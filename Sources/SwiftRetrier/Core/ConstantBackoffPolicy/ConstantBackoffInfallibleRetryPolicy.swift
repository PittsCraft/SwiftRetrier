import Foundation

open class ConstantBackoffInfallibleRetryPolicy: InfallibleRetryPolicy {

    public let delay: TimeInterval

    init(delay: TimeInterval = ConstantBackoffConstants.defaultDelay) {
        self.delay = delay
    }

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        delay
    }

    public func freshInfallibleCopy() -> InfallibleRetryPolicy {
        self
    }
}
