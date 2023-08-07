import Foundation
import Combine

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: RetryPolicy = Policy.exponentialBackoff(),
    conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    job: @escaping Job<Value>
) -> AnySingleOutputRetrier<Value> {
    if let conditionPublisher {
        return ConditionalRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            .eraseToAnySingleOutputRetrier()
    }
    return SimpleRetrier(policy: policy, job: job)
        .eraseToAnySingleOutputRetrier()
}

public func retrier<Value, P: Publisher<Bool, Never>>(
    policy: RetryPolicy = Policy.exponentialBackoff(),
    conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    repeatDelay: TimeInterval,
    job: @escaping Job<Value>
) -> SimpleRepeater<Value> {
    SimpleRepeater(policy: policy, conditionPublisher: conditionPublisher, repeatDelay: repeatDelay, job: job)
}
