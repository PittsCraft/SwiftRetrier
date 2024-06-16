import Foundation

public struct GiveUpOnPolicyWrapper: RetryPolicy {

    private let wrapped: RetryPolicy
    private let giveUpCriterium: @Sendable (AttemptFailure) -> Bool

    public init(wrapped: RetryPolicy, giveUpCriterium: @escaping @Sendable (AttemptFailure) -> Bool) {
        self.wrapped = wrapped
        self.giveUpCriterium = giveUpCriterium
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        self.wrapped.retryDelay(for: attemptFailure)
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision {
        guard !giveUpCriterium(attemptFailure) else {
            return .giveUp
        }
        return wrapped.shouldRetry(on: attemptFailure)
    }

    public func policyAfter(attemptFailure: AttemptFailure, delay: TimeInterval) -> any RetryPolicy {
        GiveUpOnPolicyWrapper(
            wrapped: wrapped.policyAfter(attemptFailure: attemptFailure, delay: delay),
            giveUpCriterium: giveUpCriterium
        )
    }
}
