import Foundation

public enum RetrierEvent<Output> {
    case attemptSuccess(Output)
    case attemptFailure(AttemptFailure)
    case completion(Error?)
}
