import Foundation

public typealias GiveUpCriteria = @MainActor @Sendable (
    _ attemptFailure: AttemptFailure,
    _ nestedPolicyDelay: TimeInterval
) -> Bool

public enum GiveUpCriterias {

    static func timeout(_ timeout: TimeInterval) -> GiveUpCriteria {
        { attempt, wrappedDelay in
            let nextAttemptStart = Date().addingTimeInterval(wrappedDelay)
            return nextAttemptStart >= attempt.trialStart.addingTimeInterval(timeout)
        }
    }

    static func maxAttempts(_ maxAttempts: UInt) -> GiveUpCriteria {
        { attempt, _ in
            attempt.index >= maxAttempts - 1
        }
    }

    static func finalError(_ finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> GiveUpCriteria {
        { attempt, _ in
            finalErrorCriteria(attempt.error)
        }
    }
}
