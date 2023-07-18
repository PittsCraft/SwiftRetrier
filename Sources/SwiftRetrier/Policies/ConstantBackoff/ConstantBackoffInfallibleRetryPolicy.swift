import Foundation

open class ConstantBackoffInfallibleRetryPolicy: InfallibleRetryPolicy {

    public let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    public func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        delay
    }

    public func freshInfallibleCopy() -> InfallibleRetryPolicy {
        self
    }
}
