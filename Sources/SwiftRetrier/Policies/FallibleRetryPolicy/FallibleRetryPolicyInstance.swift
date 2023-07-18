import Foundation

/// Simple wrapper for `RetryPolicy`, meant to expose concrete instances via static members
public struct FallibleRetryPolicyInstance: FallibleRetryPolicy {
    private var wrapped: FallibleRetryPolicy

    init(_ wrapped: FallibleRetryPolicy) {
        self.wrapped = wrapped
    }

    public func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision {
        wrapped.shouldRetry(attemptIndex: attemptIndex, lastError: lastError)
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        FallibleRetryPolicyInstance(wrapped.freshFallibleCopy())
    }
}

