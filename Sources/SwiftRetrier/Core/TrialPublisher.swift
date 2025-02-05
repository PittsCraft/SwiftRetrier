import Foundation
@preconcurrency import Combine

struct TrialPublisher<Value: Sendable>: Sendable {
    typealias Failure = Never

    let policy: RetryPolicy
    let job: Job<Value>
}

extension TrialPublisher: Publisher {
    typealias Output = RetrierEvent<Value>

    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, RetrierEvent<Value> == S.Input {
        let subscription = TrialSubscription(job: job, policy: policy, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

@preconcurrency private class TrialSubscription<Value: Sendable, S: Subscriber>: Subscription
where Never == S.Failure, RetrierEvent<Value> == S.Input {

    typealias Output = RetrierEvent<Value>
    typealias Failure = Never

    let job: Job<Value>
    private var policy: RetryPolicy
    private let subscriber: S

    private var demand: Subscribers.Demand = .none
    private var startDate: Date?
    private var retryDecision: RetryDecision = .retry(delay: 0)
    private var attemptFailure: AttemptFailure?
    private var lastFailureDate: Date?
    private var succeeded: Bool = false
    private var terminated: Bool = false
    private var task: Task<Void, Never>?
    private let lock = NSRecursiveLock()

    var combineIdentifier: CombineIdentifier = .init()

    init(job: @escaping Job<Value>, policy: RetryPolicy, subscriber: S) {
        self.job = job
        self.policy = policy
        self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {
        handle(demand: demand)
    }

    func cancel() {
        lock.withLock {
            terminated = true
            task?.cancel()
        }
    }

    private func handle(demand: Subscribers.Demand) {
        lock.withLock {
            guard !terminated else { return }
            self.demand += demand
            let shouldContinue = self.demand.max ?? .max > 0 && task == nil
            if shouldContinue {
                task = Task {
                    await continueTrial()
                }
            }
        }
    }

    @MainActor
    private func continueTrial() async {
        guard !succeeded else {
            lock.withLock {
                guard !terminated else { return }
                _ = subscriber.receive(.completion(nil))
                subscriber.receive(completion: .finished)
                terminated = true
            }
            return
        }
        switch retryDecision {
        case .giveUp:
            lock.withLock {
                guard !terminated else { return }
                _ = subscriber.receive(.completion(attemptFailure?.error))
                subscriber.receive(completion: .finished)
                terminated = true
            }
        case .retry(let delay):
            let lastFailureDate = lastFailureDate ?? Date()
            let remainingDelay = lastFailureDate.timeIntervalSince1970 + delay - Date().timeIntervalSince1970
            await attempt(delay: remainingDelay)
        }
    }

    private func onAttemptFinished(with demand: Subscribers.Demand) {
        self.demand -= 1
        task = nil
        handle(demand: demand)
    }

    @MainActor
    private func attempt(delay: TimeInterval) async {
        let startDate: Date
        if let storedDate = self.startDate {
            startDate = storedDate
        } else {
            startDate = Date()
            self.startDate = startDate
        }
        if delay > 0 {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
               return // Task was cancelled
            }
        }
        if let attemptFailure {
            policy = policy.policyAfter(attemptFailure: attemptFailure, delay: delay)
        }
        do {
            let value = try await job()
            lock.withLock {
                guard !terminated else { return }
                succeeded = true
                let demand = subscriber.receive(.attemptSuccess(value))
                onAttemptFinished(with: demand)
            }
        } catch {
            lock.withLock {
                guard !terminated else { return }
                self.lastFailureDate = Date()
                let index: UInt = if let attemptFailure {
                    attemptFailure.index + 1
                } else {
                    0
                }
                let attemptFailure = AttemptFailure(trialStart: startDate, index: index, error: error)
                self.attemptFailure = attemptFailure
                self.retryDecision = policy.shouldRetry(on: attemptFailure)
                let demand = subscriber.receive(.attemptFailure(attemptFailure))
                onAttemptFinished(with: demand)
            }
        }
    }
}
