import Foundation

public extension InfallibleRetryPolicyInstance {
    static func exponentialBackoff(
        timeSlot: TimeInterval = 0.2,
        maxDelay: TimeInterval = 3600,
        jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = .full
    ) -> InfallibleRetryPolicyInstance {
        let wrapped = ExponentialBackoffInfallibleRetryPolicy(timeSlot: timeSlot,
                                                              maxDelay: maxDelay,
                                                              jitter: jitter)
        return .init(wrapped)
    }

    static func constantBackoff(delay: TimeInterval = 1) -> InfallibleRetryPolicyInstance {
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
