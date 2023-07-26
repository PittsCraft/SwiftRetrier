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

    func repeating(withDelay repeatDelay: TimeInterval) -> ColdInfallibleRepeater {
        ColdInfallibleRepeater(policy: self, repeatDelay: repeatDelay, conditionPublisher: nil)
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> SimpleInfallibleRetrier<Output> {
        SimpleInfallibleRetrier(policy: self, job: job)
    }
}
