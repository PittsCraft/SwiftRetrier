import Foundation
import Combine

public struct Retrier: @unchecked Sendable {
    let policy: RetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

extension Retrier: RetrierBuilder {

    public func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> Retrier {
        let policy = policy.giveUp(on: giveUpCriteria)
        return Retrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    public func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> Retrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        Retrier(
            policy: policy,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher)
        )
    }
}

public extension Retrier {

    func repeating(withDelay repeatDelay: TimeInterval) -> Repeater {
        Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func job<T>(_ job: @escaping Job<T>) -> JobRetrier<T> {
        JobRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
    }
}
