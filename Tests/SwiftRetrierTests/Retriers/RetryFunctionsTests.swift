import Foundation
import XCTest
@testable import SwiftRetrier

class RetryFunctionsTests: XCTestCase {

    func testFallibleAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        Task {
            try await fallibleRetry(with: .constantBackoff(delay: 0.1, maxAttempts: 1),
                                    job: { throw nsError },
                                    attemptFailureHandler: { _ in
                expectation.fulfill()
            })
        }
        wait(for: [expectation], timeout: 0.2)
    }

    func testInfallibleAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        let task = Task {
            var fulfilled = false
            try await retry(with: .constantBackoff(delay: 0.1),
                            job: { throw nsError },
                            attemptFailureHandler: { _ in
                if !fulfilled {
                    expectation.fulfill()
                    fulfilled = true
                }
            })
        }
        wait(for: [expectation], timeout: 0.2)
        task.cancel()
    }

    func testInfallibleRepeatSubscriptionCancellationPropagated() {
        _ = retry(repeatEvery: 0.1,
                  propagateSubscriptionCancellation: true,
                  with: .constantBackoff(delay: 0.1),
                  job: {
            DispatchQueue.main.sync {
                XCTFail("Job should not be called")
            }
        })
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: 0.15)
    }

    func testFallibleRepeatSubscriptionCancellationPropagated() {
        _ = fallibleRetry(repeatEvery: 0.1,
                          propagateSubscriptionCancellation: true,
                          with: .constantBackoff(delay: 0.05),
                          job: {
            XCTFail("Job should not be called")
        })
        .sink(receiveCompletion: { _ in
        }, receiveValue: { _ in })
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: 0.15)
    }
}
