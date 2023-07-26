import Foundation
import Combine

// MARK: Fallible Retriers

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: FallibleRetryPolicy,
    conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    job: @escaping Job<Value>
) -> AnySingleOutputFallibleRetrier<Value> {
    if let conditionPublisher {
        return ConditionalFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            .eraseToAnySingleOutputFallibleRetrier()
    }
    return SimpleFallibleRetrier(policy: policy, job: job)
        .eraseToAnySingleOutputFallibleRetrier()
}

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: FallibleRetryPolicy,
    conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    repeatDelay: TimeInterval,
    job: @escaping Job<Value>
) -> FallibleRepeater<Value> {
    FallibleRepeater(repeatDelay: repeatDelay, policy: policy, conditionPublisher: conditionPublisher, job: job)
}

// MARK: Infallible Retriers

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: InfallibleRetryPolicy = Policy.exponentialBackoff(),
    conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    job: @escaping Job<Value>
) -> AnySingleOutputInfallibleRetrier<Value> {
    if let conditionPublisher {
        return ConditionalInfallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            .eraseToAnySingleOutputInfallibleRetrier()
    }
    return SimpleInfallibleRetrier(policy: policy, job: job)
        .eraseToAnySingleOutputInfallibleRetrier()
}

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: InfallibleRetryPolicy = Policy.exponentialBackoff(),
    conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    repeatDelay: TimeInterval,
    job: @escaping Job<Value>
) -> InfallibleRepeater<Value> {
    InfallibleRepeater(policy: policy, conditionPublisher: conditionPublisher, repeatDelay: repeatDelay, job: job)
}
