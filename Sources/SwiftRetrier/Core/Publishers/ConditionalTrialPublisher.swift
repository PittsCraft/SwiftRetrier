import Foundation
@preconcurrency import Combine

struct ConditionalTrialPublisher<Value: Sendable>: Sendable {
    typealias Failure = Never

    let policy: RetryPolicy
    let job: Job<Value>
    let conditionPublisher: AnyPublisher<Bool, Never>
}

extension ConditionalTrialPublisher: Publisher {
    typealias Output = RetrierEvent<Value>

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, RetrierEvent<Value> == S.Input {
        let subscription = ConditionalRetrierSubscription(
            job: job,
            policy: policy,
            subscriber: subscriber,
            conditionPublisher: conditionPublisher
        )
        subscriber.receive(subscription: subscription)
    }
}

/// - The condition drives whether a  trial subscription should be instantiated or not
/// - The demand is forwarded to the trial subscription
/// - This conditional subscription completes as soon as:
///    - the condition publisher completes with no value published or false as the last value
///    - the trial subscription completes properly
@preconcurrency private class ConditionalRetrierSubscription<Value: Sendable, S: Subscriber>
where Never == S.Failure, RetrierEvent<Value> == S.Input {

    typealias Output = RetrierEvent<Value>
    typealias Failure = Never

    private let trialPublisher: TrialPublisher<Value>
    private let subscriber: S

    private var conditionSubscription: AnyCancellable?
    private var trialSubscription: (any Subscription)?
    private var demand: Subscribers.Demand = .none
    private var condition: Bool?
    private var terminated: Bool = false
    private let lock = NSRecursiveLock()

    var combineIdentifier: CombineIdentifier = .init()

    init(
        job: @escaping Job<Value>,
        policy: RetryPolicy,
        subscriber: S,
        conditionPublisher: AnyPublisher<Bool, Never>
    ) {
        self.trialPublisher = TrialPublisher(policy: policy, job: job)
        self.subscriber = subscriber
        bind(conditionPublisher: conditionPublisher)
    }
}

extension ConditionalRetrierSubscription: Subscription {

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

private extension ConditionalRetrierSubscription {

    func bind(conditionPublisher: AnyPublisher<Bool, Never>) {
        conditionSubscription = conditionPublisher
            .removeDuplicates()
            .sink(receiveCompletion: { [unowned self] _ in
                lock.withLock {
                    handleConditionCompletion()
                }
            }, receiveValue: { [unowned self] condition in
                lock.withLock {
                    self.condition = condition
                    handleTrialConditionsChange()
                }
            })
    }

    func handleTrialConditionsChange() {
        guard !terminated else { return }
        let shouldTry = (condition ?? false)
        if shouldTry {
            if trialSubscription == nil {
                trialPublisher
                    .receive(subscriber: self)
            }
        } else {
            cancelTrialSubscription()
        }
    }

    func handleConditionCompletion() {
        guard !terminated else { return }
        if condition.map({ !$0 }) ?? false {
            cancel()
            subscriber.receive(completion: .finished)
        }
    }

    func handle(demand: Subscribers.Demand) {
        self.demand += demand
        trialSubscription?.request(demand) // Relay extra demand to active subscription
    }

    func cancelTrialSubscription() {
        if let trialSubscription {
            self.trialSubscription = nil
            trialSubscription.cancel()
        }
    }

    func terminate() {
        terminated = true
        conditionSubscription?.cancel()
        cancelTrialSubscription()
    }
}

extension ConditionalRetrierSubscription: Subscriber {
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
            self.demand -= 1
            let demand = subscriber.receive(input)
            handle(demand: demand)
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {
        lock.withLock {
            if trialSubscription == nil {
                return // Ignore completion from canceled subscription
            }
            terminate()
            subscriber.receive(completion: completion)
        }
    }
}
