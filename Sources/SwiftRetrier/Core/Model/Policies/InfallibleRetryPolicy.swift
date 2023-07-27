import Foundation

public protocol InfallibleRetryPolicy {
    func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval
    func freshInfallibleCopy() -> InfallibleRetryPolicy
}

public extension InfallibleRetryPolicy {

    func toFallibleRetryPolicy() -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: self)
    }
}
