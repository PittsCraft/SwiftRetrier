import Foundation
import Combine

private func subscribeAndAwait<R>(
    retrier: R,
    attemptFailureHandler: ((Error) -> Void)?
) async throws -> R.Output where R: SingleOutputRetrier {
    var cancellables = Set<AnyCancellable>()
    if let attemptFailureHandler {
        retrier.failurePublisher()
            .sink(receiveCompletion: { _ in },
                  receiveValue: attemptFailureHandler)
            .store(in: &cancellables)
    }
    do {
        let result = try await retrier.cancellableValue
        cancellables.removeAll()
        return result
    } catch {
        cancellables.removeAll()
        throw error
    }
}

// MARK: - Fallible Retry

public func withRetries<Value, P: Publisher<Bool, Never>>(
    policy: FallibleRetryPolicy,
    onlyWhen conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    attemptFailureHandler: ((Error) -> Void)? = nil,
    job: @escaping Job<Value>
) async throws -> Value {
    try await subscribeAndAwait(retrier: retrier(policy: policy,
                                                 conditionPublisher: conditionPublisher,
                                                 job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func withRetries<Value, P: Publisher<Bool, Never>>(
    policy: FallibleRetryPolicy,
    repeatEvery repeatDelay: TimeInterval,
    propagateCancellation: Bool = false,
    onlyWhen conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    job: @escaping Job<Value>
) -> AnyPublisher<Value, Error> {
    retrier(policy: policy,
            conditionPublisher: conditionPublisher,
            repeatDelay: repeatDelay,
            job: job)
        .successPublisher(propagateCancellation: propagateCancellation)
}

// MARK: - Retry Infallible

public func withRetries<Value, P: Publisher<Bool, Never>>(
    policy: InfallibleRetryPolicy = Policy.exponentialBackoff(),
    onlyWhen conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    attemptFailureHandler: ((Error) -> Void)? = nil,
    job: @escaping Job<Value>
) async throws -> Value {
    try await subscribeAndAwait(retrier: retrier(policy: policy,
                                                 conditionPublisher: conditionPublisher,
                                                 job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func withRetries<Value, P: Publisher<Bool, Never>>(
    policy: InfallibleRetryPolicy = Policy.exponentialBackoff(),
    repeatEvery repeatDelay: TimeInterval,
    propagateCancellation: Bool = false,
    onlyWhen conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    job: @escaping Job<Value>
) -> AnyPublisher<Value, Never> {
    retrier(policy: policy,
            conditionPublisher: conditionPublisher,
            repeatDelay: repeatDelay,
            job: job)
    .successPublisher(propagateCancellation: propagateCancellation)
}
