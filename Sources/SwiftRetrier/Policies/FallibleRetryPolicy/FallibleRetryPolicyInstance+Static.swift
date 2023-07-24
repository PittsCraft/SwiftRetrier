import Foundation

/// Built-in concrete instances and custom wrapper builder
public extension FallibleRetryPolicyInstance {

    static func exponentialBackoff(
        timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
        maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
        jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = ExponentialBackoffConstants.defaultJitter,
        maxAttempts: UInt = UInt.max,
        giveUpOn: @escaping (Error) -> Bool = { _ in false },
        retryOn: @escaping (Error) -> Bool = { _ in false }
    ) -> FallibleRetryPolicyInstance {
        let wrapped = ExponentialBackoffFallibleRetryPolicy(timeSlot: timeSlot,
                                                            maxDelay: maxDelay,
                                                            jitter: jitter,
                                                            maxAttempts: maxAttempts,
                                                            giveUpOn: giveUpOn,
                                                            retryOn: retryOn)
        return .init(wrapped)
    }

    static func constantBackoff(delay: TimeInterval = ConstantBackoffConstants.defaultDelay,
                                maxAttempts: UInt = UInt.max,
                                giveUpOn: @escaping (Error) -> Bool = { _ in false },
                                retryOn: @escaping (Error) -> Bool = { _ in false }) -> FallibleRetryPolicyInstance {
        let wrapped = ConstantBackoffFallibleRetryPolicy(delay: delay,
                                                         maxAttempts: maxAttempts,
                                                         giveUpOn: giveUpOn,
                                                         retryOn: retryOn)
        return .init(wrapped)
    }

    static func immediate(maxAttempts: UInt = UInt.max,
                          giveUpOn: @escaping (Error) -> Bool = { _ in false },
                          retryOn: @escaping (Error) -> Bool = { _ in false }) -> FallibleRetryPolicyInstance {
        constantBackoff(delay: 0, maxAttempts: maxAttempts, giveUpOn: giveUpOn, retryOn: retryOn)
    }

    static func custom(_ policy: FallibleRetryPolicy) -> FallibleRetryPolicyInstance {
        .init(policy)
    }
}
