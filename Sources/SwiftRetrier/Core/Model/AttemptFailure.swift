import Foundation

public struct AttemptFailure: Sendable {
    public let trialStart: Date
    public let index: UInt
    public let error: Error
}
