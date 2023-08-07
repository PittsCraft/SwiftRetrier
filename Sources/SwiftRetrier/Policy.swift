import Foundation

public struct Policy {
    public static func exponentialBackoff(
        timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
        maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
        jitter: ExponentialBackoffRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
    ) -> ExponentialBackoffRetryPolicy {
        ExponentialBackoffRetryPolicy(timeSlot: timeSlot,
                                                maxDelay: maxDelay,
                                                jitter: jitter)
    }

    public static func constantDelay(
        _ delay: TimeInterval = ConstantDelayConstants.defaultDelay
    ) -> ConstantDelayRetryPolicy {
        ConstantDelayRetryPolicy(delay: delay)
    }

    public static func noDelay() -> ConstantDelayRetryPolicy {
        constantDelay(0)
    }
}
