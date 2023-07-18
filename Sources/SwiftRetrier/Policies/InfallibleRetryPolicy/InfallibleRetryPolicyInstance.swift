import Foundation

/// Simple wrapper for `InfallibleRetryPolicy`, meant to expose concrete instances via static members
public struct InfallibleRetryPolicyInstance: InfallibleRetryPolicy {
    private let wrapped: InfallibleRetryPolicy

    init(_ wrapped: InfallibleRetryPolicy) {
        self.wrapped = wrapped
    }

    public func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        wrapped.retryDelay(attemptIndex: attemptIndex, lastError: lastError)
    }

    public func freshInfallibleCopy() -> InfallibleRetryPolicy {
        self.wrapped.freshInfallibleCopy()
    }
}
