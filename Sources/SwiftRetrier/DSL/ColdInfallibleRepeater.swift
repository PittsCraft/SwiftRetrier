import Foundation
import Combine

public struct ColdInfallibleRepeater {
    let policy: InfallibleRetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdInfallibleRepeater {

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdInfallibleRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdInfallibleRepeater(policy: policy,
                               repeatDelay: repeatDelay,
                               conditionPublisher: conditionPublisher.eraseToAnyPublisher())
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> InfallibleRepeater<Output> {
        retrier(policy: policy, repeatDelay: repeatDelay, job: job)
    }
}
