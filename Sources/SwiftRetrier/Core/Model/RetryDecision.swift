import Foundation

public enum RetryDecision: Sendable {
    case giveUp
    case retry(delay: TimeInterval)
}
