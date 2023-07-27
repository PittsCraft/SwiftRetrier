import Foundation
import Combine

public struct ColdFallibleRetrier {
    let policy: FallibleRetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdFallibleRetrier {

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

    func retry(on retryCriterium: @escaping (AttemptFailure) -> Bool) -> ColdFallibleRetrier {
        let policy = RetryOnFalliblePolicyWrapper(wrapped: policy, retryCriterium: retryCriterium)
        return ColdFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func retryOnErrors(matching retryCriterium: @escaping (Error) -> Bool) -> ColdFallibleRetrier {
        retry(on: { retryCriterium($0.error) })
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdFallibleRetrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdFallibleRetrier(policy: policy,
                            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher))
    }

    func `repeat`(withDelay repeatDelay: TimeInterval) -> ColdFallibleRepeater {
        ColdFallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> AnySingleOutputFallibleRetrier<Output> {
        if let conditionPublisher {
            return ConditionalFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
                .eraseToAnySingleOutputFallibleRetrier()
        }
        return SimpleFallibleRetrier(policy: policy, job: job).eraseToAnySingleOutputFallibleRetrier()
    }

    @discardableResult
    func callAsFunction<Output>(_ job: @escaping Job<Output>) -> AnySingleOutputFallibleRetrier<Output> {
        execute(job)
    }
}
