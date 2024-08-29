import Foundation
import Combine

public protocol RetrierBuilder {
    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> Self
    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> Self where P: Publisher, P.Output == Bool, P.Failure == Never
}

public extension RetrierBuilder {

    func giveUpAfter(maxAttempts: UInt) -> Self {
        giveUp(on: GiveUpCriterias.maxAttempts(maxAttempts))
    }

    func giveUpAfter(timeout: TimeInterval) -> Self {
        giveUp(on: GiveUpCriterias.timeout(timeout))
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> Self {
        giveUp(on: GiveUpCriterias.finalError(finalErrorCriteria))
    }
}
