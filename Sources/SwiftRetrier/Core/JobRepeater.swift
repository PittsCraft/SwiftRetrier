import Foundation
@preconcurrency import Combine

public struct JobRepeater<Value: Sendable>: Sendable {
    public typealias Failure = Never
    public typealias Output = RetrierEvent<Value>

    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
    let receiveEvent: @Sendable @MainActor (RetrierEvent<Value>) -> Void
    let job: Job<Value>

    private let publisher: RepeatingTrialPublisher<Value>

    init(
        policy: RetryPolicy,
        repeatDelay: TimeInterval,
        conditionPublisher: AnyPublisher<Bool, Never>?,
        receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void = { _ in },
        job: @escaping Job<Value>
    ) {
        self.policy = policy
        self.repeatDelay = repeatDelay
        self.conditionPublisher = conditionPublisher
        self.receiveEvent = receiveEvent
        self.job = job
        self.publisher = RepeatingTrialPublisher<Value>(
            policy: policy,
            repeatDelay: repeatDelay,
            job: job,
            conditionPublisher: conditionPublisher ?? Just(true).eraseToAnyPublisher()
        )
    }
}

extension JobRepeater: Publisher {

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        publisher
            .handleEvents(receiveOutput: { output in
                MainActor.assumeIsolated {
                    receiveEvent(output)
                }
            })
            .receive(subscriber: subscriber)
    }
}
