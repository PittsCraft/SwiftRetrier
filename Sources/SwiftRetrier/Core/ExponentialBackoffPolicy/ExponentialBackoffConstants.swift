import Foundation

public enum ExponentialBackoffConstants {
    public static let defaultTimeSlot: TimeInterval = 0.5
    public static let defaultMaxDelay: TimeInterval = 60
    public static let defaultDecorrelatedJitterGrowthFactor: Double = 3
    public static let defaultJitter: ExponentialBackoffRetryPolicy.Jitter = .full
}
