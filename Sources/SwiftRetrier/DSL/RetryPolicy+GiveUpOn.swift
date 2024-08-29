import Foundation

public extension RetryPolicy {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self, giveUpCriteria: giveUpCriteria)
    }

    func giveUpAfter(maxAttempts: UInt) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self, giveUpCriteria: GiveUpCriterias.maxAttempts(maxAttempts))
    }

    func giveUpAfter(timeout: TimeInterval) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self, giveUpCriteria: GiveUpCriterias.timeout(timeout))
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self, giveUpCriteria: GiveUpCriterias.finalError(finalErrorCriteria))
    }
}
