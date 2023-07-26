import Foundation

public class RetryingOnFalliblePolicyWrapper: FallibleRetryPolicy {
    private let wrapped: FallibleRetryPolicy
    private let retryCriterium: (Error) -> Bool

    public init(wrapped: FallibleRetryPolicy, retryCriterium: @escaping (Error) -> Bool = { _ in false }) {
        self.wrapped = wrapped
        self.retryCriterium = retryCriterium
    }

    public func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        wrapped.retryDelay(attemptIndex: attemptIndex, lastError: lastError)
    }

    public func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision {
        guard !retryCriterium(lastError) else {
            return .retry(delay: retryDelay(attemptIndex: attemptIndex, lastError: lastError))
        }
        return wrapped.shouldRetry(attemptIndex: attemptIndex, lastError: lastError)
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        RetryingOnFalliblePolicyWrapper(wrapped: wrapped.freshFallibleCopy(), retryCriterium: retryCriterium)
    }
}
