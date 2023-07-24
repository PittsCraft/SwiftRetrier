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

var trueFalseTruePublisher: AnyPublisher<Bool, Never> {
    [false, true]
        .publisher
    // Delay for proper time to interrupt job with `defaultJobDuration`
        .delay(for: .seconds(defaultWaitingTime), scheduler: OperationQueue.main)
        .prepend(Just(true))
        .eraseToAnyPublisher()
}

func taskWait(_ time: TimeInterval = defaultWaitingTime) async throws {
    try await Task.sleep(nanoseconds: nanoseconds(time))
}

extension FallibleRetryPolicyInstance {
    static func testDefault(maxAttempts: UInt = UInt.max) -> FallibleRetryPolicyInstance {
        .constantBackoff(delay: defaultRetryDelay, maxAttempts: maxAttempts)
    }
}

extension InfallibleRetryPolicyInstance {
    static func testDefault() -> InfallibleRetryPolicyInstance {
        .constantBackoff(delay: defaultRetryDelay)
    }
}
