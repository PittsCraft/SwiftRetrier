import Foundation

public protocol FallibleRetryPolicy {
    func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision
    func freshFallibleCopy() -> FallibleRetryPolicy
}

public extension FallibleRetryPolicy {

    func instance() -> FallibleRetryPolicyInstance {
        .custom(self)
    }
}
