import Foundation
import XCTest
@testable import SwiftRetrier

class SingleOutputFallibleRetrierTests<R: SingleOutputFallibleRetrier>: XCTestCase {
    var retrier: ((FallibleRetryPolicyInstance, @escaping Job<Void>) -> R)!

    let successJob: Job<Void> = {}
    let failureJob: Job<Void> = { throw NSError() }

    private var instance: R?

    func buildRetrier(_ policy: FallibleRetryPolicyInstance, _ job: @escaping Job<Void>) -> R {
        let retrier = retrier(policy, job)
        instance = retrier
        return retrier
    }

    override func tearDown() {
        instance?.cancel()
        instance = nil
        super.tearDown()
    }

    @MainActor
    func test_async_value_throws_on_trial_failure() async {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1), failureJob)
        do {
            _ = try await retrier.value
            XCTFail("Unexpected success")
        } catch {}
    }

    func test_publisher_finished_received_on_trial_failure() {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1), successJob)
        let expectation = expectation(description: "Finished received")
        let cancellable = retrier
            .attemptFailurePublisher
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_publisher_attempt_failure_received_on_trial_failure() {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1), failureJob)
        let expectation = expectation(description: "Attempt failure received")
        let cancellable = retrier
            .attemptFailurePublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: { result in
                expectation.fulfill()
            })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == SingleOutputFallibleRetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
