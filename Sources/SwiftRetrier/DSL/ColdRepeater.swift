import Foundation
@preconcurrency import Combine

public struct ColdRepeater: Sendable {
    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdRepeater {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> ColdRepeater {
        let policy = policy.giveUp(on: giveUpCriteria)
        return ColdRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(maxAttempts: UInt) -> ColdRepeater {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return ColdRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(timeout: TimeInterval) -> ColdRepeater {
        let policy = policy.giveUpAfter(timeout: timeout)
        return ColdRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> ColdRepeater {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriteria)
        return ColdRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdRepeater(policy: policy,
                     repeatDelay: repeatDelay,
                     conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher))
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> Repeater<Output> {
        Repeater(policy: policy, repeatDelay: repeatDelay, job: job)
    }

    @discardableResult
    func callAsFunction<Output>(_ job: @escaping Job<Output>) -> Repeater<Output> {
        execute(job)
    }
}
