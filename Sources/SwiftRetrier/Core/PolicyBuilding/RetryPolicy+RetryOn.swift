import Foundation

public extension RetryPolicy {

    func retry(on retryCriterium: @escaping (AttemptFailure) -> Bool) -> RetryPolicy {
        RetryOnPolicyWrapper(wrapped: self, retryCriterium: retryCriterium)
    }

    func retryOnErrors(matching retryCriterium: @escaping (Error) -> Bool) -> RetryPolicy {
        retry(on: { retryCriterium($0.error) })
    }
}
