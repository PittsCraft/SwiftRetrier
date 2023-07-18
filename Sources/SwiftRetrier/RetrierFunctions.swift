import Foundation
import Combine

// MARK: Fallible Retriers

public func fallibleRetrier<Value>(
    policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>
) -> AnySingleOutputFallibleRetrier<Value> {
    SimpleRetrier(policy: policy, job: job)
        .eraseToAnySingleOutputFallibleRetrier()
}

public func fallibleRetrier<Value, P: Publisher<Bool, Never>>(
    policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    conditionPublisher: P,
    job: @escaping Job<Value>
) -> AnySingleOutputFallibleRetrier<Value> {
    ConditionalFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
        .eraseToAnySingleOutputFallibleRetrier()
}

public func fallibleRetrier<Value>(
    repeatDelay: TimeInterval,
    policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>
) -> FallibleRepeater<Value> {
    FallibleRepeater(repeatDelay: repeatDelay, policy: policy, job: job)
}

public func fallibleRetrier<Value, P: Publisher<Bool, Never>>(
    repeatDelay: TimeInterval,
    policy: FallibleRetryPolicyInstance = .exponentialBackoff(),
    conditionPublisher: P,
    job: @escaping Job<Value>
) -> FallibleRepeater<Value> {
    FallibleRepeater(repeatDelay: repeatDelay, policy: policy, conditionPublisher: conditionPublisher, job: job)
}

// MARK: Infallible Retriers

public func retrier<Value>(
    policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>
) -> AnySingleOutputInfallibleRetrier<Value> {
    SimpleInfallibleRetrier(policy: policy, job: job)
        .eraseToAnySingleOutputInfallibleRetrier()
}

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    conditionPublisher: P,
    job: @escaping Job<Value>
) -> AnySingleOutputInfallibleRetrier<Value> {
    ConditionalInfallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
        .eraseToAnySingleOutputInfallibleRetrier()
}

public func retrier<Value>(
    repeatDelay: TimeInterval,
    policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    job: @escaping Job<Value>
) -> InfallibleRepeater<Value> {
    InfallibleRepeater(repeatDelay: repeatDelay, policy: policy, job: job)
}

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: InfallibleRetryPolicyInstance = .exponentialBackoff(),
    conditionPublisher: P,
    repeatDelay: TimeInterval,
    job: @escaping Job<Value>
) -> InfallibleRepeater<Value> {
    InfallibleRepeater(repeatDelay: repeatDelay, policy: policy, conditionPublisher: conditionPublisher, job: job)
}
