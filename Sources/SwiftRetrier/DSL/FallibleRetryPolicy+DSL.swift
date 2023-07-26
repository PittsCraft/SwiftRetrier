import Foundation

public extension FallibleRetryPolicy {

    func retryingOn(errorMatching retryCriterium: @escaping (Error) -> Bool) -> FallibleRetryPolicy {
        RetryingOnFalliblePolicyWrapper(wrapped: self, retryCriterium: retryCriterium)
    }

    func repeating(withDelay repeatDelay: TimeInterval) -> ColdFallibleRepeater {
        ColdFallibleRepeater(policy: self, repeatDelay: repeatDelay, conditionPublisher: nil)
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> SimpleFallibleRetrier<Output> {
        SimpleFallibleRetrier(policy: self, job: job)
    }
}
