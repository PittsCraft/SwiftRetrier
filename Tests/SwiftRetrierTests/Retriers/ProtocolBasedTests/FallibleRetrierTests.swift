import Foundation
import XCTest
@testable import SwiftRetrier

class FallibleRetrierTests<R: FallibleRetrier>: XCTestCase {

    var retrier: ((FallibleRetryPolicyInstance, @escaping Job<Void>) -> R)!

    private let successJob: () -> Void = {}
    private let failureJob: () throws -> Void = { throw nsError }

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

    func test_publisher_trial_failure_received() {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1), failureJob)
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .attemptPublisher
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_successPublisher_trial_failure_received() {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1), failureJob)
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .attemptSuccessPublisher
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_failurePublisher_trial_failure_received() {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1), failureJob)
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .attemptFailurePublisher
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_cancellation_propagated_to_job() {
        let cancellationExpectation = expectation(description: "Cancellation catched")
        var fulfilled = false
        let retrier = buildRetrier(.constantBackoff(delay: 0.1, maxAttempts: 1), {
            do {
                try await Task.sleep(nanoseconds: nanoseconds(0.1))
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
        wait(for: [cancellationExpectation], timeout: 0.2)
    }

    func test_failure_on_policy_give_up() {
        let retrier = buildRetrier(.constantBackoff(maxAttempts: 1),
                                   failureJob)
        let expectation = expectation(description: "Retrier should fail when the policy gives up")
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: {
                if case .failure = $0 {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.3)
        cancellable.cancel()
    }

    @MainActor
    func test_deallocated_some_time_after_failure() async throws {
        weak var retrier = retrier(.constantBackoff(maxAttempts: 1), failureJob)
        try await Task.sleep(nanoseconds: nanoseconds(0.1))
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
