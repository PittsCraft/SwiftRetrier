import Foundation
import XCTest
@testable import SwiftRetrier

class WithRetriesFunctionsTests: XCTestCase {

    func testFallibleAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        Task {
            let policy = Policy
                .testDefault()
                .failingOn(maxAttempts: 1)
            try await withRetries(policy: policy,
                                  attemptFailureHandler: { _ in
                expectation.fulfill()
            },
                                  job: immediateFailureJob)
        }
        wait(for: [expectation], timeout: defaultSequenceWaitingTime)
    }

    func testInfallibleAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        let task = Task {
            var fulfilled = false
            try await withRetries(policy: Policy.testDefault(),
                                  attemptFailureHandler: { _ in
                if !fulfilled {
                    expectation.fulfill()
                    fulfilled = true
                }
            },
                                  job: immediateFailureJob)
        }
        wait(for: [expectation], timeout: defaultSequenceWaitingTime)
        task.cancel()
    }

    func testInfallibleRepeatSubscriptionCancellationPropagated() {
        _ = withRetries(policy: Policy.testDefault(),
                        repeatEvery: 0.1,
                        propagateCancellation: true,
                        job: {
            DispatchQueue.main.sync {
                XCTFail("Job should not be called")
            }
        })
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: defaultSequenceWaitingTime)
    }

    func testFallibleRepeatSubscriptionCancellationPropagated() {
        _ = withRetries(policy: Policy.constantDelay(defaultWaitingTime),
                        repeatEvery: defaultRetryDelay,
                        propagateCancellation: true,
                        job: {
            XCTFail("Job should not be called")
        })
        .sink(receiveCompletion: { _ in
        }, receiveValue: { _ in })
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: defaultSequenceWaitingTime)
    }
}
