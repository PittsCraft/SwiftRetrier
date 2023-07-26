import Foundation
import Combine

public struct ColdFallibleRetrier {
    let policy: FallibleRetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdFallibleRetrier {

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdFallibleRetrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdFallibleRetrier(policy: policy,
                            conditionPublisher: conditionPublisher.eraseToAnyPublisher())
    }

    func repeating(withDelay repeatDelay: TimeInterval) -> ColdFallibleRepeater {
        ColdFallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    func retryingOn(errorMatching retryCriterium: @escaping (Error) -> Bool) -> ColdFallibleRetrier {
        let policy = RetryingOnFalliblePolicyWrapper(wrapped: policy, retryCriterium: retryCriterium)
        return ColdFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> AnySingleOutputFallibleRetrier<Output> {
        if let conditionPublisher {
            return ConditionalFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
                .eraseToAnySingleOutputFallibleRetrier()
        }
        return SimpleFallibleRetrier(policy: policy, job: job).eraseToAnySingleOutputFallibleRetrier()
    }
}
