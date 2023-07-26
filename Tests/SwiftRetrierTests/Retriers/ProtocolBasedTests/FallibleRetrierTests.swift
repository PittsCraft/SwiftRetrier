import Foundation
import XCTest
@testable import SwiftRetrier

class FallibleRetrierTests<R: FallibleRetrier>: XCTestCase {

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

    func test_publisher_trial_failure_received() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .publisher()
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    func test_successPublisher_trial_failure_received() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .successPublisher()
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    func test_failurePublisher_trial_failure_received() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .failurePublisher()
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    func test_cancellation_propagated_to_job() {
        let cancellationExpectation = expectation(description: "Cancellation catched")
        var fulfilled = false
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), {
            do {
                try await taskWait(defaultJobDuration)
            } catch {
                if !fulfilled {
                    cancellationExpectation.fulfill()
                    fulfilled = true
                }
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            retrier.cancel()
        }
        wait(for: [cancellationExpectation], timeout: defaultSequenceWaitingTime)
    }

    func test_failure_on_policy_give_up() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1),
                                   immediateFailureJob)
        let expectation = expectation(description: "Retrier should fail when the policy gives up")
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: {
                if case .failure = $0 {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultSequenceWaitingTime)
        cancellable.cancel()
    }

    @MainActor
    func test_deallocated_some_time_after_failure() async throws {
        weak var retrier = retrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        try await taskWait()
        XCTAssertNil(retrier)
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == FallibleRetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
