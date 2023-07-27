import Foundation
import Combine

public struct ColdInfallibleRetrier {
    let policy: InfallibleRetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdInfallibleRetrier {

    func giveUp(on giveUpCriterium: @escaping (AttemptFailure) -> Bool) -> ColdFallibleRetrier {
        let policy = policy.giveUp(on: giveUpCriterium)
        return ColdFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpAfter(maxAttempts: UInt) -> ColdFallibleRetrier {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return ColdFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func giveUpOnErrors(matching finalErrorCriterium: @escaping (Error) -> Bool) -> ColdFallibleRetrier {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriterium)
        return ColdFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdInfallibleRetrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdInfallibleRetrier(policy: policy,
                              conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher))
    }

    func `repeat`(withDelay repeatDelay: TimeInterval) -> ColdInfallibleRepeater {
        ColdInfallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> AnySingleOutputInfallibleRetrier<Output> {
        retrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
    }

    @discardableResult
    func callAsFunction<Output>(_ job: @escaping Job<Output>) -> AnySingleOutputInfallibleRetrier<Output> {
        execute(job)
    }
}
