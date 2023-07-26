import Foundation
import Combine

public struct Retrier {
    let policy: InfallibleRetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension Retrier {

    func failingOn(
        maxAttempts: UInt = UInt.max,
        errorMatching failureCriterium: @escaping (Error) -> Bool = { _ in false }
    ) -> ColdFallibleRetrier {
        let policy = policy.failingOn(maxAttempts: maxAttempts, errorMatching: failureCriterium)
        return ColdFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher)
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> Retrier where P: Publisher, P.Output == Bool, P.Failure == Never {
        Retrier(policy: policy,
                conditionPublisher: conditionPublisher.eraseToAnyPublisher())
    }

    func repeating(withDelay repeatDelay: TimeInterval) -> ColdInfallibleRepeater {
        ColdInfallibleRepeater(policy: policy, repeatDelay: repeatDelay, conditionPublisher: conditionPublisher)
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> AnySingleOutputInfallibleRetrier<Output> {
        retrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
    }
}
