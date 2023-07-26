import Foundation

public extension InfallibleRetryPolicy {

    func failingOn(
        maxAttempts: UInt = UInt.max,
        errorMatching failureCriterium: @escaping (Error) -> Bool = { _ in false }
    ) -> FallibleRetryPolicy {
        ToFallibleRetryPolicyWrapper(wrapped: self, giveUpCriterium: { attemptIndex, lastError in
            return attemptIndex >= maxAttempts - 1 || failureCriterium(lastError)
        })
    }
}
