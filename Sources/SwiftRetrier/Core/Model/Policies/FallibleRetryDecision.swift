import Foundation

public enum FallibleRetryDecision {
    case giveUp
    case retry(delay: TimeInterval)
}
