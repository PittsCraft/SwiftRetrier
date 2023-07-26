import Foundation

public func withExponentialBackoff(
    timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
    maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
    jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
) -> Retrier {
    let policy = ExponentialBackoffInfallibleRetryPolicy(timeSlot: timeSlot,
                                                         maxDelay: maxDelay,
                                                         jitter: jitter)
    return Retrier(policy: policy, conditionPublisher: nil)
}

public func withConstantDelay(
    _ delay: TimeInterval = ConstantBackoffConstants.defaultDelay
) -> Retrier {
    let policy = ConstantBackoffInfallibleRetryPolicy(delay: delay)
    return Retrier(policy: policy, conditionPublisher: nil)
}

public func withNoDelay() -> Retrier {
    withConstantDelay(0)
}
