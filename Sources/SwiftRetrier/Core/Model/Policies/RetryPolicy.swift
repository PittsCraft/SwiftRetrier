import Foundation

public protocol RetryPolicy: Sendable {
    func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision
    func policyAfter(attemptFailure: AttemptFailure, delay: TimeInterval) -> any RetryPolicy
}
