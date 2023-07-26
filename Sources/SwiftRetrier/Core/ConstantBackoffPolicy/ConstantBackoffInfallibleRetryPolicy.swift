import Foundation

open class ConstantBackoffInfallibleRetryPolicy: InfallibleRetryPolicy {

    public let delay: TimeInterval

    init(delay: TimeInterval = ConstantBackoffConstants.defaultDelay) {
        self.delay = delay
    }

    public func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        delay
    }

    public func freshInfallibleCopy() -> InfallibleRetryPolicy {
        self
    }
}
