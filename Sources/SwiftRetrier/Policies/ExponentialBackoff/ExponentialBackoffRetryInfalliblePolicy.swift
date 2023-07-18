import Foundation

open class ExponentialBackoffInfallibleRetryPolicy: InfallibleRetryPolicy {

    public enum Jitter {
        case none
        case full
        case decorrelated
    }

    public let timeSlot: TimeInterval
    public let maxDelay: TimeInterval
    public let jitter: Jitter
    private var previousDelay: TimeInterval?

    public init(timeSlot: TimeInterval = 0.2,
                maxDelay: TimeInterval = 3600,
                jitter: Jitter = .full) {
        self.timeSlot = timeSlot
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    public func exponentiationBySquaring<T: BinaryInteger>(_ y: T, _ x: T, _ n: T) -> T {
        precondition(n >= 0)
        if n == 0 {
            return y
        } else if n == 1 {
            return y * x
        } else if n.isMultiple(of: 2) {
            return exponentiationBySquaring(y, x * x, n / 2)
        } else { // n is odd
            return exponentiationBySquaring(y * x, x * x, (n - 1) / 2)
        }
    }

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

    public func decorrelatedJitterDelay(attemptIndex: UInt) -> TimeInterval {
        let delay: TimeInterval
        if let previousDelay {
            let max = max(timeSlot, 3 * previousDelay)
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
        case .decorrelated:
            return decorrelatedJitterDelay(attemptIndex: attemptIndex)
        }
    }

    open func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        min(maxDelay, uncappedDelay(attemptIndex: attemptIndex))
    }

    public func freshInfallibleCopy() -> InfallibleRetryPolicy {
        ExponentialBackoffInfallibleRetryPolicy(timeSlot: timeSlot, maxDelay: maxDelay, jitter: jitter)
    }
}
