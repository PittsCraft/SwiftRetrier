import Foundation

public extension FallibleRetryPolicy {

    func retryingOn(errorMatching retryCriterium: @escaping (Error) -> Bool) -> FallibleRetryPolicy {
        RetryingOnFalliblePolicyWrapper(wrapped: self, retryCriterium: retryCriterium)
    }
}
