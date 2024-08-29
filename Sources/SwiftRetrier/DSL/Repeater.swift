import Foundation
@preconcurrency import Combine

public struct Repeater: Sendable {
    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

extension Repeater: RetrierBuilder {

    public func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> Repeater {
        let policy = policy.giveUp(on: giveUpCriteria)
        return Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    public func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> Repeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        Repeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher)
        )
    }
}

public extension Repeater {

    func job<T>(_ job: @escaping Job<T>) -> JobRepeater<T> {
        JobRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher, job: job)
    }
}
