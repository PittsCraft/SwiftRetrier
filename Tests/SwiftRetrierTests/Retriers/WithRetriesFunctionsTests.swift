import Foundation
import XCTest
@testable import SwiftRetrier

class WithRetriesFunctionsTests: XCTestCase {

    func testAttemptFailureHandlerCalled() {
        let expectation = expectation(description: "Attempt failure handler called")
        Task {
            let policy = Policy
                .testDefault()
                .giveUpAfter(maxAttempts: 1)
            try await withRetries(policy: policy,
                                  attemptFailureHandler: { _ in
                expectation.fulfill()
            },
                                  job: immediateFailureJob)
        }
        wait(for: [expectation], timeout: defaultSequenceWaitingTime)
    }

    func testRepeatSubscriptionCancellationPropagated() {
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
}
