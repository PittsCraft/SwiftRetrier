import Foundation
import Combine
@testable import SwiftRetrier

let factor = Double(2)
let defaultRetryDelay = 0.1 * factor
let repeatDelay = 0.1 * factor
let defaultJobDuration = 0.1 * factor
let defaultSequenceWaitingTime = 0.5 * factor

let defaultWaitingTime = defaultJobDuration / 2
let immediateSuccessJob: Job<Void> = {}
let defaultError = NSError(domain: "SwiftRetrier", code: 1412)
let immediateFailureJob: Job<Void> = { throw defaultError }
let defaultAsyncJob: Job<Void> = { try await taskWait(defaultJobDuration) }
func asyncJob(_ duration: TimeInterval) -> Job<Void> {
    { try await taskWait(duration) }
}

func trueFalseTruePublisher(_ valueDuration: TimeInterval = defaultJobDuration / 2) -> AnyPublisher<Bool, Never> {
    [false, true]
        .publisher
        .delay(for: .seconds(valueDuration), scheduler: OperationQueue.main)
        .prepend(Just(true))
        .eraseToAnyPublisher()
}

func taskWait(_ time: TimeInterval = defaultWaitingTime) async throws {
    try await Task.sleep(nanoseconds: nanoseconds(time))
}

enum Policy {
    static func testDefault(maxAttempts: UInt = UInt.max) -> RetryPolicy {
        ConstantDelayRetryPolicy(delay: defaultRetryDelay).giveUpAfter(maxAttempts: maxAttempts)
    }

    static func testDefault() -> RetryPolicy {
        ConstantDelayRetryPolicy(delay: defaultRetryDelay)
    }
}
