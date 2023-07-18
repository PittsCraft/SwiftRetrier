import Foundation

/// Built-in concrete instances and custom wrapper builder
public extension FallibleRetryPolicyInstance {

    static func exponentialBackoff(timeSlot: TimeInterval = 0.2,
                                   maxDelay: TimeInterval = 3600,
                                   jitter: ExponentialBackoffInfallibleRetryPolicy.Jitter = .full,
                                   maxAttempts: UInt = UInt.max,
                                   giveUpOn: @escaping (Error) -> Bool = { _ in false },
                                   retryOn: @escaping (Error) -> Bool = { _ in false }) -> FallibleRetryPolicyInstance {
        let wrapped = ExponentialBackoffFallibleRetryPolicy(timeSlot: timeSlot,
                                                            maxDelay: maxDelay,
                                                            jitter: jitter,
                                                            maxAttempts: maxAttempts,
                                                            giveUpOn: giveUpOn,
                                                            retryOn: retryOn)
        return .init(wrapped)
    }

    static func constantBackoff(delay: TimeInterval = 1,
                                maxAttempts: Int = Int.max,
                                giveUpOn: @escaping (Error) -> Bool = { _ in false },
                                retryOn: @escaping (Error) -> Bool = { _ in false }) -> FallibleRetryPolicyInstance {
        let wrapped = ConstantBackoffFallibleRetryPolicy(delay: delay,
                                                         maxAttempts: maxAttempts,
                                                         giveUpOn: giveUpOn,
                                                         retryOn: retryOn)
        return .init(wrapped)
    }

    static func immediate(maxAttempts: Int = Int.max,
                          giveUpOn: @escaping (Error) -> Bool = { _ in false },
                          retryOn: @escaping (Error) -> Bool = { _ in false }) -> FallibleRetryPolicyInstance {
        constantBackoff(delay: 0, maxAttempts: maxAttempts, giveUpOn: giveUpOn, retryOn: retryOn)
    }

    static func custom(_ policy: FallibleRetryPolicy) -> FallibleRetryPolicyInstance {
        .init(policy)
    }
}
