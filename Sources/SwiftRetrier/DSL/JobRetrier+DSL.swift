import Foundation
import Combine

extension JobRetrier: JobRetrierBuilder {

    public func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> JobRetrier {
        let policy = policy.giveUp(on: giveUpCriteria)
        return JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    public func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> JobRetrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        JobRetrier(
            policy: policy,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher),
            receiveEvent: receiveEvent,
            job: job
        )
    }

    public func handleRetrierEvents(receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void) -> JobRetrier {
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

public extension JobRetrier {

    func repeating(withDelay repeatDelay: TimeInterval) -> JobRepeater<Value> {
        JobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }
}

