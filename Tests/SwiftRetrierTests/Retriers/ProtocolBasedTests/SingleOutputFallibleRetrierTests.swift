import Foundation
import XCTest
@testable import SwiftRetrier

class SingleOutputFallibleRetrierTests<R: SingleOutputFallibleRetrier>: XCTestCase {
    var retrier: ((FallibleRetryPolicy, @escaping Job<Void>) -> R)!

    private var instance: R?

    func buildRetrier(_ policy: FallibleRetryPolicy, _ job: @escaping Job<Void>) -> R {
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
        let retrier = buildRetrier(Policy.constantDelay().giveUpAfter(maxAttempts: 1), immediateFailureJob)
        do {
            _ = try await retrier.value
            XCTFail("Unexpected success")
        } catch {}
    }

    func test_publisher_finished_received_on_trial_failure() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateSuccessJob)
        let expectation = expectation(description: "Finished received")
        let cancellable = retrier
            .failurePublisher()
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    func test_publisher_attempt_failure_received_on_trial_failure() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        let expectation = expectation(description: "Attempt failure received")
        let cancellable = retrier
            .failurePublisher()
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in
                expectation.fulfill()
            })
        waitForExpectations(timeout: defaultWaitingTime)
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
