import Foundation

public protocol FallibleRetryPolicy {
    func shouldRetry(on attemptFailure: AttemptFailure) -> FallibleRetryDecision
    func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval
    func freshFallibleCopy() -> FallibleRetryPolicy
}
