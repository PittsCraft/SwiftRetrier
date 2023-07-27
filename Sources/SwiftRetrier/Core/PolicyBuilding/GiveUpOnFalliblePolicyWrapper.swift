import Foundation

public struct GiveUpOnFalliblePolicyWrapper: FallibleRetryPolicy {

    private let wrapped: FallibleRetryPolicy
    private let giveUpCriterium: (AttemptFailure) -> Bool

    public init(wrapped: FallibleRetryPolicy, giveUpCriterium: @escaping (AttemptFailure) -> Bool) {
        self.wrapped = wrapped
        self.giveUpCriterium = giveUpCriterium
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        self.wrapped.retryDelay(for: attemptFailure)
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> FallibleRetryDecision {
        guard !giveUpCriterium(attemptFailure) else {
            return .giveUp
        }
        return wrapped.shouldRetry(on: attemptFailure)
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        GiveUpOnFalliblePolicyWrapper(wrapped: wrapped.freshFallibleCopy(), giveUpCriterium: giveUpCriterium)
    }
}
