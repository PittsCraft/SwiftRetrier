import Foundation

public struct GiveUpOnPolicyWrapper: RetryPolicy {

    private let wrapped: RetryPolicy
    private let giveUpCriterium: (AttemptFailure) -> Bool

    public init(wrapped: RetryPolicy, giveUpCriterium: @escaping (AttemptFailure) -> Bool) {
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

    public func freshCopy() -> RetryPolicy {
        GiveUpOnPolicyWrapper(wrapped: wrapped.freshCopy(), giveUpCriterium: giveUpCriterium)
    }
}
