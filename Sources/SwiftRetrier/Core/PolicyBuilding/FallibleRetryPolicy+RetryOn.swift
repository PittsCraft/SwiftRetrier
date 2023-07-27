import Foundation

public extension FallibleRetryPolicy {

    func retry(on retryCriterium: @escaping (AttemptFailure) -> Bool) -> FallibleRetryPolicy {
        RetryOnFalliblePolicyWrapper(wrapped: self, retryCriterium: retryCriterium)
    }

    func retryOnErrors(matching retryCriterium: @escaping (Error) -> Bool) -> FallibleRetryPolicy {
        retry(on: { retryCriterium($0.error) })
    }
}
