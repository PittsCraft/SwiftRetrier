import Foundation

public protocol InfallibleRetryPolicy {
    func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval
    func freshInfallibleCopy() -> InfallibleRetryPolicy
}

public extension InfallibleRetryPolicy {

    func toFallibleRetryPolicy() -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: self)
    }
}
