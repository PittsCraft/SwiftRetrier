import Foundation

open class ExponentialBackoffRetryPolicy: RetryPolicy {

    public enum Jitter {
        case none
        case full
        case decorrelated(growthFactor: Double = ExponentialBackoffConstants.defaultDecorrelatedJitterGrowthFactor)
    }

    public let timeSlot: TimeInterval
    public let maxDelay: TimeInterval
    public let jitter: Jitter
    private var previousDelay: TimeInterval?

    public init(timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
                maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
                jitter: Jitter = ExponentialBackoffConstants.defaultJitter) {
        self.timeSlot = timeSlot
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    public func exponentiationBySquaring<T: BinaryInteger>(_ base: T, _ multiplier: T, _ exponent: T) -> T {
        precondition(exponent >= 0)
        if exponent == 0 {
            return base
        } else if exponent == 1 {
            return base * multiplier
        } else if exponent.isMultiple(of: 2) {
            return exponentiationBySquaring(base, multiplier * multiplier, exponent / 2)
        } else { // exponent is odd
            return exponentiationBySquaring(base * multiplier, multiplier * multiplier, (exponent - 1) / 2)
        }
    }

    // swiftlint:disable:next line_length
    // See https://stackoverflow.com/questions/24196689/how-to-get-the-power-of-some-integer-in-swift-language/39021464#39021464
    public func pow<T: BinaryInteger>(_ base: T, _ power: T) -> T {
        return exponentiationBySquaring(1, base, power)
    }

    public func noJitterDelay(attemptIndex: UInt) -> TimeInterval {
        let maxSlots = pow(UInt(2), attemptIndex)
        return timeSlot * TimeInterval(maxSlots)
    }

    public func fullJitterDelay(attemptIndex: UInt) -> TimeInterval {
        TimeInterval.random(in: 0...noJitterDelay(attemptIndex: attemptIndex))
    }

    public func decorrelatedJitterDelay(attemptIndex: UInt, growthFactor: Double) -> TimeInterval {
        let delay: TimeInterval
        if let previousDelay {
            let max = max(timeSlot, growthFactor * previousDelay)
            delay = TimeInterval.random(in: timeSlot...max)
        } else {
            delay = fullJitterDelay(attemptIndex: attemptIndex)
        }
        previousDelay = delay
        return delay
    }

    public func uncappedDelay(attemptIndex: UInt) -> TimeInterval {
        switch jitter {
        case .none:
            return noJitterDelay(attemptIndex: attemptIndex)
        case .full:
            return fullJitterDelay(attemptIndex: attemptIndex)
        case .decorrelated(let growthFactor):
            return decorrelatedJitterDelay(attemptIndex: attemptIndex, growthFactor: growthFactor)
        }
    }

    open func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        min(maxDelay, uncappedDelay(attemptIndex: attemptFailure.index))
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision {
        .retry(delay: retryDelay(for: attemptFailure))
    }

    public func freshCopy() -> RetryPolicy {
        ExponentialBackoffRetryPolicy(timeSlot: timeSlot, maxDelay: maxDelay, jitter: jitter)
    }
}
