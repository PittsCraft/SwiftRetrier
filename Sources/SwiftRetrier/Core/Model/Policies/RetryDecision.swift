import Foundation

public enum RetryDecision {
    case giveUp
    case retry(delay: TimeInterval)
}
