import Foundation
import Combine

public struct ColdInfallibleRepeater {
    let policy: InfallibleRetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdInfallibleRepeater {

    func giveUp(on giveUpCriterium: @escaping (AttemptFailure) -> Bool) -> ColdFallibleRepeater {
        let policy = policy.giveUp(on: giveUpCriterium)
        return ColdFallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(maxAttempts: UInt) -> ColdFallibleRepeater {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return ColdFallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func giveUpOnErrors(matching finalErrorCriterium: @escaping (Error) -> Bool) -> ColdFallibleRepeater {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriterium)
        return ColdFallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdInfallibleRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdInfallibleRepeater(policy: policy,
                               repeatDelay: repeatDelay,
                               conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher))
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> InfallibleRepeater<Output> {
        retrier(policy: policy, repeatDelay: repeatDelay, job: job)
    }

    @discardableResult
    func callAsFunction<Output>(_ job: @escaping Job<Output>) -> InfallibleRepeater<Output> {
        execute(job)
    }
}
