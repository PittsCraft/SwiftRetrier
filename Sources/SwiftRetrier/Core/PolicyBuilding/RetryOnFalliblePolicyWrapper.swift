import Foundation

public class RetryOnFalliblePolicyWrapper: FallibleRetryPolicy {
    private let wrapped: FallibleRetryPolicy
    private let retryCriterium: (AttemptFailure) -> Bool

    public init(wrapped: FallibleRetryPolicy, retryCriterium: @escaping (AttemptFailure) -> Bool) {
        self.wrapped = wrapped
        self.retryCriterium = retryCriterium
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        wrapped.retryDelay(for: attemptFailure)
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> FallibleRetryDecision {
        guard !retryCriterium(attemptFailure) else {
            return .retry(delay: retryDelay(for: attemptFailure))
        }
        return wrapped.shouldRetry(on: attemptFailure)
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        RetryOnFalliblePolicyWrapper(wrapped: wrapped.freshFallibleCopy(), retryCriterium: retryCriterium)
    }
}
