import XCTest
@testable import SwiftRetrier
import Combine


class ConditionalRetrierTests<R: Retrier>: XCTestCase {

    var retrier: ((AnyPublisher<Bool, Never>, @escaping Job<Void>) -> R)!

    let successJob: Job<Void> = {}
    let failureJob: Job<Void> = { throw NSError() }

    private var instance: R?

    func buildRetrier(_ conditionsPublisher: AnyPublisher<Bool, Never>, _ job: @escaping Job<Void>) -> R {
        let retrier = retrier(conditionsPublisher, job)
        instance = retrier
        return retrier
    }

    override func tearDown() {
        instance?.cancel()
        instance = nil
        super.tearDown()
    }

    @MainActor
    func test_no_execution_when_no_condition() async throws {
        let condition = Empty<Bool, Never>(completeImmediately: false)
            .eraseToAnyPublisher()
        _ = buildRetrier(condition,
                    { XCTFail("Job shouldn't be executed when no condition value is emitted")})
        try await Task.sleep(nanoseconds: nanoseconds(0.05))
    }

    @MainActor
    func test_no_execution_when_condition_false() async throws {
        let condition = Just(false)
            .append(Empty(completeImmediately: false))
            .eraseToAnyPublisher()
        _ = buildRetrier(condition, {
            XCTFail("Job shouldn't be executed when false condition is emitted before completion")
        })
        try await Task.sleep(nanoseconds: nanoseconds(0.05))
    }

    func test_execution_when_condition_true() {
        let condition = Just(true)
            .eraseToAnyPublisher()
        let expectation = expectation(description: "Job executed")
        _ = buildRetrier(condition, { expectation.fulfill() })
        waitForExpectations(timeout: 0.05)
    }

    var trueFalseTruePublisher: AnyPublisher<Bool, Never> {
        [false, true]
            .publisher
            .delay(for: .seconds(0.05), scheduler: OperationQueue.main)
            .prepend(Just(true))
            .eraseToAnyPublisher()
    }

    func test_receive_attempt_error_when_trial_cancelled_by_subscription() {
        let job = {
            try await Task.sleep(nanoseconds: nanoseconds(0.1))
        }

        let expectationAttemptFailureReceived = expectation(description: "AttemptFailure received")

        let retrier = buildRetrier(trueFalseTruePublisher, job)
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: {
                if case .failure(let error) = $0 {
                    expectationAttemptFailureReceived.fulfill()
                    if !(error is CancellationError) {
                        XCTFail("Expected attempt failure to be a cancellation error")
                    }
                }
            })
        wait(for: [expectationAttemptFailureReceived], timeout: 1)
        cancellable.cancel()
    }

    @MainActor
    func test_publisher_receive_second_trial_success() async {
        let job = {
            try await Task.sleep(nanoseconds: nanoseconds(0.1))
        }
        let expectationValueReceived = expectation(description: "Success received")

        let retrier = buildRetrier(trueFalseTruePublisher, job)
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: {
                if case .success = $0 {
                    expectationValueReceived.fulfill()
                }
            })
        await fulfillment(of: [expectationValueReceived], timeout: 0.3)
        cancellable.cancel()
    }

    func test_attempt_on_failure_propagated_during_second_trial() {
        var failedOnce = false
        let ownError = NSError(domain: "domain", code: 8)
        var jobExecutionCount = 0
        let job = {
            jobExecutionCount += 1
            try await Task.sleep(nanoseconds: nanoseconds(0.1))
            if !failedOnce {
                failedOnce = true
                throw ownError
            }
        }
        let expectationOwnErrorPropagated = expectation(description: "Attempt own error propagated")

        let retrier = buildRetrier(trueFalseTruePublisher, job)
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: {
                if case .failure(let error) = $0, ownError.isEqual(error as NSError) {
                    expectationOwnErrorPropagated.fulfill()
                }
            })
        wait(for: [expectationOwnErrorPropagated], timeout: 0.5)
        cancellable.cancel()
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == ConditionalRetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
