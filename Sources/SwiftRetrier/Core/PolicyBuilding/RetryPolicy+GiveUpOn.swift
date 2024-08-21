import Foundation

public extension RetryPolicy {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self, giveUpCriteria: giveUpCriteria)
    }

    func giveUpAfter(maxAttempts: UInt) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self) { attempt, _ in
            attempt.index >= maxAttempts - 1
        }
    }

    func giveUpAfter(timeout: TimeInterval) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self) { attempt, wrappedDelay in
            let nextAttemptStart = Date().addingTimeInterval(wrappedDelay)
            return nextAttemptStart >= attempt.trialStart.addingTimeInterval(timeout)
        }
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> RetryPolicy {
        GiveUpCriteriaPolicyWrapper(wrapped: self) { attempt, _ in
            finalErrorCriteria(attempt.error)
        }
    }
}
