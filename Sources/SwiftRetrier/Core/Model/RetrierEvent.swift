import Foundation

public enum RetrierEvent<Output: Sendable>: Sendable {
    case attemptSuccess(Output)
    case attemptFailure(AttemptFailure)
    case completion(Error?)
}
