import Foundation
import XCTest
@testable import SwiftRetrier

class RetryFunctionsTests: XCTestCase {

    func testFallibleAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        Task {
            try await fallibleRetry(with: .constantBackoff(delay: defaultRetryDelay, maxAttempts: 1),
                                    job: immediateFailureJob,
                                    attemptFailureHandler: { _ in
                expectation.fulfill()
            })
        }
        wait(for: [expectation], timeout: defaultSequenceWaitingTime)
    }

    func testInfallibleAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        let task = Task {
            var fulfilled = false
            try await retry(with: .testDefault(),
                            job: immediateFailureJob,
                            attemptFailureHandler: { _ in
                if !fulfilled {
                    expectation.fulfill()
                    fulfilled = true
                }
            })
        }
        wait(for: [expectation], timeout: defaultSequenceWaitingTime)
        task.cancel()
    }

    func testInfallibleRepeatSubscriptionCancellationPropagated() {
        _ = retry(repeatEvery: 0.1,
                  propagateSubscriptionCancellation: true,
                  with: .testDefault(),
                  job: {
            DispatchQueue.main.sync {
                XCTFail("Job should not be called")
            }
        })
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: defaultSequenceWaitingTime)
    }

    func testFallibleRepeatSubscriptionCancellationPropagated() {
        _ = fallibleRetry(repeatEvery: defaultRetryDelay,
                          propagateSubscriptionCancellation: true,
                          with: .constantBackoff(delay: defaultWaitingTime),
                          job: {
            XCTFail("Job should not be called")
        })
        .sink(receiveCompletion: { _ in
        }, receiveValue: { _ in })
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: defaultSequenceWaitingTime)
    }
}
