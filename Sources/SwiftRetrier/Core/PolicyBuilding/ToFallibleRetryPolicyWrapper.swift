import Foundation

public class ToFallibleRetryPolicyWrapper: FallibleRetryPolicy {

    private let wrapped: InfallibleRetryPolicy
    private let giveUpCriterium: (UInt, Error) -> Bool

    public init(wrapped: InfallibleRetryPolicy, giveUpCriterium: @escaping (UInt, Error) -> Bool = { _, _ in false }) {
        self.wrapped = wrapped
        self.giveUpCriterium = giveUpCriterium
    }

    public func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        wrapped.retryDelay(attemptIndex: attemptIndex, lastError: lastError)
    }

    public func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision {
        guard !giveUpCriterium(attemptIndex, lastError) else {
            return .giveUp
        }
        return .retry(delay: wrapped.retryDelay(attemptIndex: attemptIndex, lastError: lastError))
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: wrapped.freshInfallibleCopy(), giveUpCriterium: giveUpCriterium)
    }
}
