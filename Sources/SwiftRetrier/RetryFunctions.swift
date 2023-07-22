import Foundation
import Combine

private func subscribeAndAwait<R>(
    retrier: R,
    attemptFailureHandler: ((Error) -> Void)?
) async throws -> R.Output where R: SingleOutputFallibleRetrier {
    var cancellables = Set<AnyCancellable>()
    if let attemptFailureHandler {
        retrier.attemptFailurePublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: attemptFailureHandler)
            .store(in: &cancellables)
    }
    let result = try await retrier.cancellableValue
    cancellables.removeAll()
    return result
}

private func subscribeAndAwait<R>(
    retrier: R,
    attemptFailureHandler: ((Error) -> Void)?
) async throws -> R.Output where R: SingleOutputInfallibleRetrier {
    var cancellables = Set<AnyCancellable>()
    if let attemptFailureHandler {
        retrier.attemptFailurePublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: attemptFailureHandler)
            .store(in: &cancellables)
    }
    let result = try await retrier.value
    cancellables.removeAll()
    return result
}

// MARK: - Fallible Retry

public func fallibleRetry<Value>(
    with policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>,
    attemptFailureHandler: ((Error) -> Void)? = nil
) async throws -> Value {
    try await subscribeAndAwait(retrier: SimpleRetrier<Value>(policy: policy, job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func fallibleRetry<Value, P: Publisher<Bool, Never>>(
    with policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    conditionPublisher: P,
    job: @escaping Job<Value>,
    attemptFailureHandler: ((Error) -> Void)? = nil
) async throws -> Value {
    try await subscribeAndAwait(retrier: ConditionalFallibleRetrier(policy: policy,
                                                                    conditionPublisher: conditionPublisher,
                                                                    job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func fallibleRetry<Value>(
    repeatEvery repeatDelay: TimeInterval,
    propagateSubscriptionCancellation: Bool = false,
    with policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>
) -> AnyPublisher<Value, Error> {
    let repeater = FallibleRepeater(repeatDelay: repeatDelay, policy: policy, job: job)
    if propagateSubscriptionCancellation {
        return repeater
            .attemptSuccessPublisher
            .handleEvents(receiveCancel: { [repeater] in repeater.cancel() })
            .eraseToAnyPublisher()
    } else {
        return repeater
            .attemptSuccessPublisher
    }
}

public func fallibleRetry<Value, P: Publisher<Bool, Never>>(
    repeatEvery repeatDelay: TimeInterval,
    propagateSubscriptionCancellation: Bool = false,
    with policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    onlyWhen conditionPublisher: P,
    job: @escaping Job<Value>
) -> AnyPublisher<Value, Error> {
    let repeater = FallibleRepeater(repeatDelay: repeatDelay,
                                    policy: policy,
                                    conditionPublisher: conditionPublisher,
                                    job: job)
    if propagateSubscriptionCancellation {
        return repeater
            .attemptSuccessPublisher
            .handleEvents(receiveCancel: { [repeater] in repeater.cancel() })
            .eraseToAnyPublisher()
    } else {
        return repeater
            .attemptSuccessPublisher
    }
}

// MARK: - Retry Infallible

public func retry<Value>(
    with policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>,
    attemptFailureHandler: ((Error) -> Void)? = nil
) async throws -> Value {
    try await subscribeAndAwait(retrier: SimpleInfallibleRetrier(policy: policy, job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func retry<Value, P: Publisher<Bool, Never>>(
    with policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    onlyWhen conditionPublisher: P,
    job: @escaping Job<Value>,
    attemptFailureHandler: ((Error) -> Void)? = nil
) async throws -> Value {
    try await subscribeAndAwait(retrier: ConditionalInfallibleRetrier(policy: policy,
                                                                      conditionPublisher: conditionPublisher,
                                                                      job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func retry<Value>(
    repeatEvery repeatDelay: TimeInterval,
    propagateSubscriptionCancellation: Bool = false,
    with policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>
) -> AnyPublisher<Value, Never> {
    let repeater = InfallibleRepeater(repeatDelay: repeatDelay, policy: policy, job: job)
    if propagateSubscriptionCancellation {
        return repeater
            .attemptSuccessPublisher
            .handleEvents(receiveCancel: { [repeater] in repeater.cancel() })
            .eraseToAnyPublisher()
    } else {
        return repeater
            .attemptSuccessPublisher
    }
}

public func retry<Value, P: Publisher<Bool, Never>>(
    repeatEvery repeatDelay: TimeInterval,
    propagateSubscriptionCancellation: Bool = false,
    with policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    onlyWhen conditionPublisher: P,
    job: @escaping Job<Value>
) -> AnyPublisher<Value, Never> {
    let repeater = InfallibleRepeater(repeatDelay: repeatDelay,
                                      policy: policy,
                                      conditionPublisher: conditionPublisher,
                                      job: job)
    if propagateSubscriptionCancellation {
        return repeater
            .attemptSuccessPublisher
            .handleEvents(receiveCancel: { [repeater] in repeater.cancel() })
            .eraseToAnyPublisher()
    } else {
        return repeater
            .attemptSuccessPublisher
    }
}
