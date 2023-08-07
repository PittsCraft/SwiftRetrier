import Foundation

public func withExponentialBackoff(
    timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
    maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
    jitter: ExponentialBackoffRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
) -> ColdRetrier {
    let policy = ExponentialBackoffRetryPolicy(timeSlot: timeSlot,
                                                         maxDelay: maxDelay,
                                                         jitter: jitter)
    return ColdRetrier(policy: policy, conditionPublisher: nil)
}

public func withConstantDelay(
    _ delay: TimeInterval = ConstantDelayConstants.defaultDelay
) -> ColdRetrier {
    let policy = ConstantDelayRetryPolicy(delay: delay)
    return ColdRetrier(policy: policy, conditionPublisher: nil)
}

public func withNoDelay() -> ColdRetrier {
    withConstantDelay(0)
}
