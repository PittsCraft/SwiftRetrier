import Foundation
@preconcurrency import Combine

public struct Repeater: Sendable {
    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension Repeater {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> Repeater {
        let policy = policy.giveUp(on: giveUpCriteria)
        return Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(maxAttempts: UInt) -> Repeater {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(timeout: TimeInterval) -> Repeater {
        let policy = policy.giveUpAfter(timeout: timeout)
        return Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> Repeater {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriteria)
        return Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> Repeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        Repeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher)
        )
    }
}
