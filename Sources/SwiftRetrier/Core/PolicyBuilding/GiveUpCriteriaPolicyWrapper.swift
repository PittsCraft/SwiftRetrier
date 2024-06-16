import Foundation

public typealias GiveUpCriteria = @Sendable (
    _ attemptFailure: AttemptFailure,
    _ nestedPolicyDelay: TimeInterval
) -> Bool

public struct GiveUpCriteriaPolicyWrapper: RetryPolicy {

    private let wrapped: RetryPolicy
    private let giveUpCriteria: GiveUpCriteria

    public init(wrapped: RetryPolicy, giveUpCriteria: @escaping GiveUpCriteria) {
        self.wrapped = wrapped
        self.giveUpCriteria = giveUpCriteria
    }

    public func shouldRetry(on attemptFailure: AttemptFailure) -> RetryDecision {
        return switch wrapped.shouldRetry(on: attemptFailure) {
        case .giveUp:
                .giveUp
        case .retry(let delay):
            if giveUpCriteria(attemptFailure, delay) {
                .giveUp
            } else {
                .retry(delay: delay)
            }
        }
    }

    public func policyAfter(attemptFailure: AttemptFailure, delay: TimeInterval) -> any RetryPolicy {
        GiveUpCriteriaPolicyWrapper(
            wrapped: wrapped.policyAfter(attemptFailure: attemptFailure, delay: delay),
            giveUpCriteria: giveUpCriteria
        )
    }
}
