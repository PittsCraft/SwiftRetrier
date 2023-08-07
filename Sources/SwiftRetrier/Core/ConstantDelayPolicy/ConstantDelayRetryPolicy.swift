import Foundation

open class ConstantDelayRetryPolicy: RetryPolicy {

    public let delay: TimeInterval

    init(delay: TimeInterval = ConstantDelayConstants.defaultDelay) {
        self.delay = delay
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        delay
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision {
        .retry(delay: retryDelay(for: attemptFailure))
    }

    public func freshCopy() -> RetryPolicy {
        self
    }
}
