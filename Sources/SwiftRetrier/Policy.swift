import Foundation

public enum Policy {
    public static func exponentialBackoff(
        timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
        maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
        jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
    ) -> ExponentialBackoffInfallibleRetryPolicy {
        ExponentialBackoffInfallibleRetryPolicy(timeSlot: timeSlot,
                                                maxDelay: maxDelay,
                                                jitter: jitter)
    }

    public static func constantDelay(
        _ delay: TimeInterval = ConstantBackoffConstants.defaultDelay
    ) -> ConstantBackoffInfallibleRetryPolicy {
        ConstantBackoffInfallibleRetryPolicy(delay: delay)
    }

    public static func noDelay() -> ConstantBackoffInfallibleRetryPolicy {
        constantDelay(0)
    }
}
