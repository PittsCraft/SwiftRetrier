import Foundation
import Combine

public struct ColdFallibleRepeater {
    let policy: FallibleRetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdFallibleRepeater {

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

    func retry(on retryCriterium: @escaping (AttemptFailure) -> Bool) -> ColdFallibleRepeater {
        let policy = RetryOnFalliblePolicyWrapper(wrapped: policy, retryCriterium: retryCriterium)
        return ColdFallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func retryOnErrors(matching retryCriterium: @escaping (Error) -> Bool) -> ColdFallibleRepeater {
        retry(on: { retryCriterium($0.error) })
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdFallibleRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdFallibleRepeater(policy: policy,
                             repeatDelay: repeatDelay,
                             conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher))
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> FallibleRepeater<Output> {
        FallibleRepeater(policy: policy, repeatDelay: repeatDelay, job: job)
    }

    @discardableResult
    func callAsFunction<Output>(_ job: @escaping Job<Output>) -> FallibleRepeater<Output> {
        execute(job)
    }
}
