import Foundation

public extension FallibleRetryPolicy {

    func giveUp(on giveUpCriterium: @escaping (AttemptFailure) -> Bool) -> FallibleRetryPolicy {
        GiveUpOnFalliblePolicyWrapper(wrapped: self, giveUpCriterium: giveUpCriterium)
    }

    func giveUpAfter(maxAttempts: UInt) -> FallibleRetryPolicy {
        GiveUpOnFalliblePolicyWrapper(wrapped: self, giveUpCriterium: { $0.index >= maxAttempts - 1})
    }

    func giveUpOnErrors(matching finalErrorCriterium: @escaping (Error) -> Bool) -> FallibleRetryPolicy {
        GiveUpOnFalliblePolicyWrapper(wrapped: self, giveUpCriterium: { finalErrorCriterium($0.error) })
    }
}
