import Foundation
import Combine

public extension JobRetrier {

    func repeating(withDelay repeatDelay: TimeInterval) -> JobRepeater<T> {
        JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> JobRetrier {
        let policy = policy.giveUp(on: giveUpCriteria)
        return JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpAfter(maxAttempts: UInt) -> JobRetrier {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpAfter(timeout: TimeInterval) -> JobRetrier {
        let policy = policy.giveUpAfter(timeout: timeout)
        return JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> JobRetrier {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriteria)
        return JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> JobRetrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher),
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func handleRetrierEvents(receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<T>) -> Void) -> JobRetrier {
        return JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher,
            receiveEvent: {
                self.receiveEvent($0)
                receiveEvent($0)
            },
            job: job
        )
    }
}

