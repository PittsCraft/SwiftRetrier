import Foundation

public protocol GiveUpModifiable {
    associatedtype Modified

    func giveUp(on giveUpCriterium: @escaping (AttemptFailure) -> Bool) -> Modified
}

public extension GiveUpModifiable {
    func giveUpAfter(maxAttempts: UInt) -> Modified {
        giveUp(on: { $0.index >= maxAttempts - 1 })
    }

    func giveUpOnErrors(matching finalErrorCriterium: @escaping (Error) -> Bool) -> Modified {
        giveUp(on: { finalErrorCriterium($0.error) })
    }
}
