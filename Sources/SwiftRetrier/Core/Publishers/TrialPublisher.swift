import Foundation
@preconcurrency import Combine

struct TrialPublisher<Value: Sendable>: Sendable {
    typealias Failure = Never

    let policy: RetryPolicy
    let job: Job<Value>
}

extension TrialPublisher: Publisher {
    typealias Output = RetrierEvent<Value>

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, RetrierEvent<Value> == S.Input {
        let subscription = TrialSubscription(job: job, policy: policy, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

@preconcurrency private class TrialSubscription<Value: Sendable, S: Subscriber>
where Never == S.Failure, RetrierEvent<Value> == S.Input {

    typealias Output = RetrierEvent<Value>
    typealias Failure = Never

    private let job: Job<Value>
    private var policy: RetryPolicy // Will change after each failure
    private let subscriber: S

    private var demand: Subscribers.Demand = .none
    /// Trial start date, will be set on first demand
    private var startDate: Date?
    /// Retain next action to be performed when demand allows it
    private var retryDecision: RetryDecision = .retry(delay: 0)
    /// Retain last attempt failure to provide it in completion event  in case the policy gives up
    private var attemptFailure: AttemptFailure?
    /// Retain last failure date to compute remaining retry delay to apply when demand allows it
    private var lastFailureDate: Date?
    /// Retain if the retrier succeeded to send proper completion to the subscriber when demand allows it
    private var succeeded: Bool = false
    /// Termination flag
    private var terminated: Bool = false
    /// Current delay and attempt task
    private var task: Task<Void, Never>?
    /// Reentrant lock, especially allows subscriber to cancel the subscription on any event sent from a locked block
    private let lock = NSRecursiveLock()

    var combineIdentifier: CombineIdentifier = .init()

    init(job: @escaping Job<Value>, policy: RetryPolicy, subscriber: S) {
        self.job = job
        self.policy = policy
        self.subscriber = subscriber
    }
}

extension TrialSubscription: Subscription {

    func request(_ demand: Subscribers.Demand) {
        handle(demand: demand)
    }

    func cancel() {
        lock.withLock {
            terminated = true
            task?.cancel()
        }
    }
}

private extension TrialSubscription {

    /// Trigger next trial step when relevant: demand > 0, no step currently executing, not terminated
    func handle(demand: Subscribers.Demand) {
        lock.withLock {
            guard !terminated else { return }
            self.demand += demand
            let shouldContinue = self.demand.max ?? .max > 0 && task == nil
            if shouldContinue {
                task = Task {
                    await nextTrialStep()
                }
            }
        }
    }

    /// Continue trial. Should be called only when demand > 0 and exclusively.
    ///
    /// Steps can either be: success handling, failure (give up) handling, or new attempt execution.
    @MainActor
    func nextTrialStep() async {
        lock.withLock {
            guard !succeeded else {
                successStep()
                return
            }
        }
        switch retryDecision {
        case .giveUp:
            lock.withLock {
                failureStep()
            }
        case .retry(let delay):
            let lastFailureDate = lastFailureDate ?? Date()
            let remainingDelay = lastFailureDate.timeIntervalSince1970 + delay - Date().timeIntervalSince1970
            await attemptStep(delay: remainingDelay)
        }
    }

    func successStep() {
        guard !terminated else { return }
        _ = subscriber.receive(.completion(nil))
        subscriber.receive(completion: .finished)
        terminated = true
    }

    func failureStep() {
        guard !terminated else { return }
        _ = subscriber.receive(.completion(attemptFailure?.error))
        subscriber.receive(completion: .finished)
        terminated = true
    }

    func getOrCreateStartDate() -> Date {
        if let startDate {
            return startDate
        } else {
            let startDate = Date()
            self.startDate = startDate
            return startDate
        }
    }

    @MainActor
    func attemptStep(delay: TimeInterval) async {
        // Create start date on first attempt, retrieve it for next ones
        let startDate = getOrCreateStartDate()
        // Wait if requested
        if delay > 0 {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
               return // Task was cancelled
            }
        }
        // After a failure: update policy for next attempt
        if let attemptFailure {
            policy = policy.policyAfter(attemptFailure: attemptFailure, delay: delay)
        }
        // Attempt
        do {
            let value = try await job()
            lock.withLock {
                onAttemptSuccess(value: value)
            }
        } catch {
            lock.withLock {
                onAttemptFailure(startDate: startDate, error: error)
            }
        }
    }

    func onAttemptSuccess(value: Value) {
        guard !terminated else { return }
        succeeded = true
        let demand = subscriber.receive(.attemptSuccess(value))
        // Anticipate success handling to avoid spanning another task if possible
        if demand + self.demand - 1 > 0 {
            successStep()
        } else {
            onAttemptFinished(with: demand)
        }
    }

    @MainActor
    func onAttemptFailure(startDate: Date, error: Error) {
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
        // Anticipate failure handling to avoid spanning another task if possible
        if case .giveUp = retryDecision, demand + self.demand - 1 > 0 {
            failureStep()
        } else {
            onAttemptFinished(with: demand)
        }
    }

    func onAttemptFinished(with demand: Subscribers.Demand) {
        self.demand -= 1
        task = nil
        handle(demand: demand)
    }
}
