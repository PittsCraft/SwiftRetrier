import Foundation

public protocol FallibleRetryPolicy {
    func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision
    func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval
    func freshFallibleCopy() -> FallibleRetryPolicy
}
