import Foundation

public class RetryOnPolicyWrapper: RetryPolicy {
    private let wrapped: RetryPolicy
    private let retryCriterium: (AttemptFailure) -> Bool

    public init(wrapped: RetryPolicy, retryCriterium: @escaping (AttemptFailure) -> Bool) {
        self.wrapped = wrapped
        self.retryCriterium = retryCriterium
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        wrapped.retryDelay(for: attemptFailure)
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision {
        guard !retryCriterium(attemptFailure) else {
            return .retry(delay: retryDelay(for: attemptFailure))
        }
        return wrapped.shouldRetry(on: attemptFailure)
    }

    public func freshCopy() -> RetryPolicy {
        RetryOnPolicyWrapper(wrapped: wrapped.freshCopy(), retryCriterium: retryCriterium)
    }
}
