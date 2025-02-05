import Foundation
@preconcurrency import Combine

public struct JobRetrier<Value: Sendable>: @unchecked Sendable {
    public typealias Failure = Never
    public typealias Output = RetrierEvent<Value>

    let policy: RetryPolicy
    let job: Job<Value>
    let conditionPublisher: AnyPublisher<Bool, Never>?
    let receiveEvent: @Sendable @MainActor (RetrierEvent<Value>) -> Void

    private let publisher: ConditionalTrialPublisher<Value>

    init(
        policy: RetryPolicy,
        conditionPublisher: AnyPublisher<Bool, Never>?,
        receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void = { _ in },
        job: @escaping Job<Value>
    ) {
        self.policy = policy
        self.conditionPublisher = conditionPublisher
        self.receiveEvent = receiveEvent
        self.job = job
        self.publisher = ConditionalTrialPublisher(
            policy: policy,
            job: job,
            conditionPublisher: conditionPublisher ?? Just(true).eraseToAnyPublisher()
        )
    }
}

extension JobRetrier: Publisher {

    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, RetrierEvent<Value> == S.Input {
        publisher
            .handleEvents(receiveOutput: { output in
                MainActor.assumeIsolated {
                    receiveEvent(output)
                }
            })
            .receive(subscriber: subscriber)
    }
}

public extension JobRetrier {

    var value: Value {
        get async throws {
            try await publisher
                .tryCompactMap {
                    switch $0 {
                    case .attemptSuccess(let value):
                        value
                    case .attemptFailure:
                        nil
                    case .completion(let error):
                        if let error {
                            throw error
                        } else {
                            nil
                        }
                    }
                }
                .cancellableFirst
        }
    }
}
