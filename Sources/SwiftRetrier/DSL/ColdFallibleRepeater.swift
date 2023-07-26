import Foundation
import Combine

public struct ColdFallibleRepeater {
    let policy: FallibleRetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
}

public extension ColdFallibleRepeater {

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdFallibleRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdFallibleRepeater(policy: policy,
                             repeatDelay: repeatDelay,
                             conditionPublisher: conditionPublisher.eraseToAnyPublisher())
    }

    @discardableResult
    func execute<Output>(_ job: @escaping Job<Output>) -> FallibleRepeater<Output> {
        FallibleRepeater(repeatDelay: repeatDelay, policy: policy, job: job)
    }
}
