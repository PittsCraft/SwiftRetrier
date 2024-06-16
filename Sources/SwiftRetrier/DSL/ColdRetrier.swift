import Foundation
import Combine

public struct ColdRetrier {
    let policy: RetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdRetrier {

    func giveUp(on giveUpCriterium: @escaping @Sendable (AttemptFailure) -> Bool) -> ColdRetrier {
        let policy = policy.giveUp(on: giveUpCriterium)
        return ColdRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(maxAttempts: UInt) -> ColdRetrier {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return ColdRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(timeout: TimeInterval) -> ColdRetrier {
        let policy = policy.giveUpAfter(timeout: timeout)
        return ColdRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpOnErrors(matching finalErrorCriterium: @escaping @Sendable (Error) -> Bool) -> ColdRetrier {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriterium)
        return ColdRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdRetrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdRetrier(policy: policy,
                    conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher))
    }

    func repeating(withDelay repeatDelay: TimeInterval) -> ColdRepeater {
        ColdRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    @discardableResult
    func execute<Output: Sendable>(_ job: @escaping Job<Output>) -> AnySingleOutputRetrier<Output> {
        if let conditionPublisher {
            return ConditionalRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
                .eraseToAnySingleOutputRetrier()
        }
        return SimpleRetrier(policy: policy, job: job).eraseToAnySingleOutputRetrier()
    }

    @discardableResult
    func callAsFunction<Output: Sendable>(_ job: @escaping Job<Output>) -> AnySingleOutputRetrier<Output> {
        execute(job)
    }
}
