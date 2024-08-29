import Foundation
import Combine

public extension JobRepeater {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> JobRepeater {
        let policy = policy.giveUp(on: giveUpCriteria)
        return JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpAfter(maxAttempts: UInt) -> JobRepeater {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpAfter(timeout: TimeInterval) -> JobRepeater {
        let policy = policy.giveUpAfter(timeout: timeout)
        return JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> JobRepeater {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriteria)
        return JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> JobRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher),
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func handleRetrierEvents(receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void) -> JobRepeater {
        JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: {
                self.receiveEvent($0)
                receiveEvent($0)
            },
            job: job
        )
    }
}
