import Foundation

public class ToFallibleRetryPolicyWrapper: FallibleRetryPolicy {
    private let wrapped: InfallibleRetryPolicy

    public init(wrapped: InfallibleRetryPolicy) {
        self.wrapped = wrapped
    }

    public func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision {
        .retry(delay: wrapped.retryDelay(attemptIndex: attemptIndex, lastError: lastError))
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: wrapped.freshInfallibleCopy())
    }
}
