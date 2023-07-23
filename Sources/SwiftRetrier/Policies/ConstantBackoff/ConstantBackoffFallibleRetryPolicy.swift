import Foundation

open class ConstantBackoffFallibleRetryPolicy: FallibleRetryPolicy {
    public let delay: TimeInterval
    public let maxAttempts: Int
    public let giveUpOn: (Error) -> Bool
    public let retryOn: (Error) -> Bool

    public init(delay: TimeInterval = 1,
                maxAttempts: Int = Int.max,
                giveUpOn: @escaping (Error) -> Bool = { _ in false },
                retryOn: @escaping (Error) -> Bool = { _ in false }) {
        self.delay = delay
        self.maxAttempts = maxAttempts
        self.giveUpOn = giveUpOn
        self.retryOn = retryOn
    }

    open func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision {
        if !retryOn(lastError) {
            guard !giveUpOn(lastError), attemptIndex < maxAttempts - 1 else {
                return .giveUp
            }
        }
        return .retry(delay: delay)
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        self
    }
}
