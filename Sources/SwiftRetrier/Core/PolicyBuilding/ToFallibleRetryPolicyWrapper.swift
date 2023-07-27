import Foundation

public class ToFallibleRetryPolicyWrapper: FallibleRetryPolicy {

    private let wrapped: InfallibleRetryPolicy
    private let giveUpCriterium: (AttemptFailure) -> Bool

    public init(wrapped: InfallibleRetryPolicy,
                giveUpCriterium: @escaping (AttemptFailure) -> Bool = { _ in false }) {
        self.wrapped = wrapped
        self.giveUpCriterium = giveUpCriterium
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        wrapped.retryDelay(for: attemptFailure)
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> FallibleRetryDecision {
        guard !giveUpCriterium(attemptFailure) else {
            return .giveUp
        }
        return .retry(delay: wrapped.retryDelay(for: attemptFailure))
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: wrapped.freshInfallibleCopy(), giveUpCriterium: giveUpCriterium)
    }
}
