import Foundation

public func withExponentialBackoff(
    timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
    maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
    jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
) -> ColdInfallibleRetrier {
    let policy = ExponentialBackoffInfallibleRetryPolicy(timeSlot: timeSlot,
                                                         maxDelay: maxDelay,
                                                         jitter: jitter)
    return ColdInfallibleRetrier(policy: policy, conditionPublisher: nil)
}

public func withConstantDelay(
    _ delay: TimeInterval = ConstantBackoffConstants.defaultDelay
) -> ColdInfallibleRetrier {
    let policy = ConstantBackoffInfallibleRetryPolicy(delay: delay)
    return ColdInfallibleRetrier(policy: policy, conditionPublisher: nil)
}

public func withNoDelay() -> ColdInfallibleRetrier {
    withConstantDelay(0)
}
