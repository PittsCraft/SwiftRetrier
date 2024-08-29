import Foundation
import Combine

extension JobRepeater: JobRetrierBuilder {

    public func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> JobRepeater {
        let policy = policy.giveUp(on: giveUpCriteria)
        return JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    public func onlyWhen<P>(
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

    public func handleRetrierEvents(receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void) -> JobRepeater {
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
