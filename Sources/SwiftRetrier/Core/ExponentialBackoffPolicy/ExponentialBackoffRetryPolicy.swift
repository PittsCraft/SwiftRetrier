import Foundation

public struct ExponentialBackoffRetryPolicy {

    public enum Jitter: Sendable {
        case none
        case full
        case decorrelated(growthFactor: Double = ExponentialBackoffConstants.defaultDecorrelatedJitterGrowthFactor)
    }

    public let timeSlot: TimeInterval
    public let maxDelay: TimeInterval
    public let jitter: Jitter
    private let previousDelay: TimeInterval?

    public init(timeSlot: TimeInterval = ExponentialBackoffConstants.defaultTimeSlot,
                maxDelay: TimeInterval = ExponentialBackoffConstants.defaultMaxDelay,
                jitter: Jitter = ExponentialBackoffConstants.defaultJitter,
                previousDelay: TimeInterval? = nil) {
        self.timeSlot = timeSlot
        self.maxDelay = maxDelay
        self.jitter = jitter
        self.previousDelay = previousDelay
    }

    private func safeMultiply(_ lhs: UInt, _ rhs: UInt) -> UInt {
        if UInt.max / rhs < lhs || UInt.max / lhs < rhs {
            UInt.max
        } else {
            lhs * rhs
        }
    }

    public func exponentiationBySquaring(base: UInt, multiplier: UInt, exponent: UInt) -> UInt {
        if exponent == .zero {
            base
        } else if exponent == 1 {
            safeMultiply(base, multiplier)
        } else if exponent.isMultiple(of: 2) {
            exponentiationBySquaring(
                base: base,
                multiplier: safeMultiply(multiplier, multiplier),
                exponent: exponent / 2
            )
        } else { // exponent is odd
            exponentiationBySquaring(
                base: safeMultiply(base, multiplier),
                multiplier: safeMultiply(multiplier, multiplier),
                exponent: (exponent - 1) / 2
            )
        }
    }

    // swiftlint:disable:next line_length
    // See https://stackoverflow.com/questions/24196689/how-to-get-the-power-of-some-integer-in-swift-language/39021464#39021464
    public func pow(_ base: UInt, _ power: UInt) -> UInt {
        exponentiationBySquaring(base: 1, multiplier: base, exponent: power)
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
}

extension ExponentialBackoffRetryPolicy: RetryPolicy {

    public func retryDelay(for attemptFailure: AttemptFailure) -> TimeInterval {
        min(maxDelay, uncappedDelay(attemptIndex: attemptFailure.index))
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision {
        .retry(delay: retryDelay(for: attemptFailure))
    }

    public func policyAfter(attemptFailure: AttemptFailure, delay: TimeInterval) -> any RetryPolicy {
        ExponentialBackoffRetryPolicy(timeSlot: timeSlot, maxDelay: maxDelay, jitter: jitter, previousDelay: delay)
    }
}
