import Foundation

public func withExponentialBackoff(
    timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
    maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
    jitter: ExponentialBackoffRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
) -> Retrier {
    let policy = ExponentialBackoffRetryPolicy(timeSlot: timeSlot,
                                               maxDelay: maxDelay,
                                               jitter: jitter)
    return Retrier(policy: policy, conditionPublisher: nil)
}

public func withConstantDelay(
    _ delay: TimeInterval = ConstantDelayConstants.defaultDelay
) -> Retrier {
    let policy = ConstantDelayRetryPolicy(delay: delay)
    return Retrier(policy: policy, conditionPublisher: nil)
}

public func withNoDelay() -> Retrier {
    withConstantDelay(0)
}
