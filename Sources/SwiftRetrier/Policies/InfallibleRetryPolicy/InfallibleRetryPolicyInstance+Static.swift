import Foundation

public extension InfallibleRetryPolicyInstance {
    static func exponentialBackoff(
        timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
        maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
        jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter
    ) -> InfallibleRetryPolicyInstance {
        let wrapped = ExponentialBackoffInfallibleRetryPolicy(timeSlot: timeSlot,
                                                              maxDelay: maxDelay,
                                                              jitter: jitter)
        return .init(wrapped)
    }

    static func constantBackoff(
        delay: TimeInterval = ConstantBackoffConstants.defaultDelay
    ) -> InfallibleRetryPolicyInstance {
        let wrapped = ConstantBackoffInfallibleRetryPolicy(delay: delay)
        return .init(wrapped)
    }

    static func immediate() -> InfallibleRetryPolicyInstance {
        constantBackoff(delay: 0)
    }

    static func custom(_ policy: InfallibleRetryPolicy) -> InfallibleRetryPolicyInstance {
        .init(policy)
    }
}
