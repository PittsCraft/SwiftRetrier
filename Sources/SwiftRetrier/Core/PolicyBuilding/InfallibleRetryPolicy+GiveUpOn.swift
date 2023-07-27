import Foundation

public extension InfallibleRetryPolicy {

    func giveUp(on giveUpCriterium: @escaping (AttemptFailure) -> Bool) -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: self, giveUpCriterium: giveUpCriterium)
    }

    func giveUpAfter(maxAttempts: UInt) -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: self, giveUpCriterium: { $0.index >= maxAttempts - 1})
    }

    func giveUpOnErrors(matching finalErrorCriterium: @escaping (Error) -> Bool) -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: self, giveUpCriterium: { finalErrorCriterium($0.error) })
    }
}
