import Foundation

public protocol RetryPolicy {
    func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision
    func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval
    func freshCopy() -> RetryPolicy
}
