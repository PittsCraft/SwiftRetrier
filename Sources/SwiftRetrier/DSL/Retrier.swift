import Foundation
import Combine

public struct Retrier: @unchecked Sendable {
    let policy: RetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension Retrier {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> Retrier {
        let policy = policy.giveUp(on: giveUpCriteria)
        return Retrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(maxAttempts: UInt) -> Retrier {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return Retrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(timeout: TimeInterval) -> Retrier {
        let policy = policy.giveUpAfter(timeout: timeout)
        return Retrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> Retrier {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriteria)
        return Retrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> Retrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        Retrier(
            policy: policy,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher)
        )
    }

    func repeating(withDelay repeatDelay: TimeInterval) -> Repeater {
        Repeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func job<T>(_ job: @escaping Job<T>) -> JobRetrier<T> {
        JobRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
    }
}
