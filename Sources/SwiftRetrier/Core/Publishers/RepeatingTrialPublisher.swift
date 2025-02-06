import Foundation
@preconcurrency import Combine

struct RepeatingTrialPublisher<Value: Sendable>: Sendable {
    typealias Failure = Never

    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let job: Job<Value>
    let conditionPublisher: AnyPublisher<Bool, Never>
}

extension RepeatingTrialPublisher: Publisher {
    typealias Output = RetrierEvent<Value>

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, RetrierEvent<Value> == S.Input {
        let subscription = RepeatingTrialSubscription(
            job: job,
            policy: policy,
            repeatDelay: repeatDelay,
            subscriber: subscriber,
            conditionPublisher: conditionPublisher
        )
        subscriber.receive(subscription: subscription)
    }
}

/// - trial subscription takes care of the conditional trial
/// - its event are relayed to the subscriber
/// - condition is still observed to make this repeating subscription complete in case the condition
/// publisher completes having emitted no value or with false as last value
/// - demand is simply maintained and relayed to trial subscription when any
/// - when a trial subscription succeeds (receiving attemptSuccess), a waiting task is started at the
/// end of which a new trial will be started
@preconcurrency private class RepeatingTrialSubscription<Value: Sendable, S: Subscriber>
where Never == S.Failure, RetrierEvent<Value> == S.Input {

    typealias Output = RetrierEvent<Value>
    typealias Failure = Never

    private var trialPublisher: ConditionalTrialPublisher<Value>!
    private let subscriber: S
    let repeatDelay: TimeInterval

    private var trialSubscription: (any Subscription)?
    private var demand: Subscribers.Demand = .none
    private var condition: Bool?
    private var terminated: Bool = false
    private var waitingTask: Task<Void, Never>?
    private let lock = NSRecursiveLock()

    var combineIdentifier: CombineIdentifier = .init()

    init(
        job: @escaping Job<Value>,
        policy: RetryPolicy,
        repeatDelay: TimeInterval,
        subscriber: S,
        conditionPublisher: AnyPublisher<Bool, Never>
    ) {
        self.subscriber = subscriber
        self.repeatDelay = repeatDelay
        let conditionPublisher = conditionPublisher
            .handleEvents(
                receiveOutput: { [unowned self] condition in
                    lock.withLock {
                        self.condition = condition
                    }
                },
                receiveCompletion: { [unowned self] _ in
                    lock.withLock {
                        handleConditionCompletion()
                    }
                }
            )
            .eraseToAnyPublisher()
        self.trialPublisher = ConditionalTrialPublisher(
            policy: policy,
            job: job,
            conditionPublisher: conditionPublisher
        )
    }
}

extension RepeatingTrialSubscription: Subscription {

    func request(_ demand: Subscribers.Demand) {
        lock.withLock {
            handle(demand: demand)
        }
    }

    func cancel() {
        lock.withLock {
            terminate()
        }
    }
}

private extension RepeatingTrialSubscription {

    func handle(demand: Subscribers.Demand) {
        self.demand += demand
        trialSubscription?.request(demand) // Relay extra demand to active subscription
        startTrialIfPossible()
    }

    func startTrialIfPossible() {
        guard !terminated else { return }
        if trialSubscription == nil, waitingTask == nil {
            trialPublisher
                .receive(subscriber: self)
        }
    }

    func handleConditionCompletion() {
        guard !terminated else { return }
        if condition.map({ !$0 }) ?? false {
            terminate()
            subscriber.receive(completion: .finished)
        }
    }

    func cancelTrialSubscription() {
        if let trialSubscription {
            self.trialSubscription = nil
            trialSubscription.cancel()
        }
    }

    func terminate() {
        terminated = true
        waitingTask?.cancel()
        cancelTrialSubscription()
    }

    func handleTrialSuccess() {
        lock.withLock {
            if trialSubscription == nil {
                return // Ignore completion from canceled subscription
            }
            trialSubscription?.cancel()
            trialSubscription = nil
            waitingTask = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: UInt64(repeatDelay * 1_000_000_000))
                } catch {
                    // Task vas cancelled
                    return
                }
                lock.withLock {
                    waitingTask = nil
                    startTrialIfPossible()
                }
            }
        }
    }
}

extension RepeatingTrialSubscription: Subscriber {
    typealias Input = RetrierEvent<Value>

    func receive(subscription: any Subscription) {
        lock.withLock {
            self.trialSubscription = subscription
            if demand > 0 { // Relay full unsatisfied demand to new subscription
                subscription.request(demand)
            }
        }
    }

    func receive(_ input: RetrierEvent<Value>) -> Subscribers.Demand {
        lock.withLock {
            if case .completion(let error) = input {
                if let error {
                    _ = subscriber.receive(.completion(error))
                    subscriber.receive(completion: .finished)
                    terminate()
                } else {
                    handleTrialSuccess()
                }
            } else {
                self.demand -= 1
                let newDemand = subscriber.receive(input)
                handle(demand: newDemand)
            }
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {
        // Ignore
    }
}
