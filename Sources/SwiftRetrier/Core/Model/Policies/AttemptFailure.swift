import Foundation

public struct AttemptFailure {
    public let trialStart: Date
    public let index: UInt
    public let error: Error
}
