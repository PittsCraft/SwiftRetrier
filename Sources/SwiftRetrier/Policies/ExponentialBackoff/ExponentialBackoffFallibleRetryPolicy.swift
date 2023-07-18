import Foundation

open class ExponentialBackoffFallibleRetryPolicy: ExponentialBackoffInfallibleRetryPolicy, FallibleRetryPolicy {

    public let maxAttempts: UInt
    public let giveUpOn: (Error) -> Bool
    public let retryOn: (Error) -> Bool

    public init(timeSlot: TimeInterval = 0.2,
                maxDelay: TimeInterval = 3600,
                jitter: Jitter = .full,
                maxAttempts: UInt = UInt.max,
                giveUpOn: @escaping (Error) -> Bool = { _ in false },
                retryOn: @escaping (Error) -> Bool = { _ in false }) {
        self.maxAttempts = maxAttempts
        self.giveUpOn = giveUpOn
        self.retryOn = retryOn
        super.init(timeSlot: timeSlot, maxDelay: maxDelay, jitter: jitter)
    }

    open func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision {
        if !retryOn(lastError) {
            guard !giveUpOn(lastError), attemptIndex < maxAttempts - 1 else {
                return .giveUp
            }
        }
        let delay = retryDelay(attemptIndex: attemptIndex, lastError: lastError)
        return .retry(delay: delay)
    }

    public func freshFallibleCopy() -> FallibleRetryPolicy {
        ExponentialBackoffFallibleRetryPolicy(timeSlot: timeSlot,
                                              maxDelay: maxDelay,
                                              jitter: jitter,
                                              maxAttempts: maxAttempts,
                                              giveUpOn: giveUpOn,
                                              retryOn: retryOn)
    }
}
