import Foundation

public protocol RetryPolicy: Sendable {
    @MainActor
    func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision
    @MainActor
    func policyAfter(attemptFailure: AttemptFailure, delay: TimeInterval) -> any RetryPolicy
}
