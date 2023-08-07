import Foundation
import XCTest
@testable import SwiftRetrier

class RetrierTests<R: Retrier>: XCTestCase {

    var retrier: ((@escaping Job<Void>) -> R)!

    private var instance: R?

    func buildRetrier(_ job: @escaping Job<Void>) -> R {
        let retrier = retrier(job)
        instance = retrier
        return retrier
    }

    override func tearDown() {
        instance?.cancel()
        instance = nil
        super.tearDown()
    }

    func test_attempt_failure_received() {
        let retrier = buildRetrier({ throw defaultError })
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .publisher()
            .sink(receiveCompletion: { _ in }, receiveValue: {
                if case .attemptFailure(let attemptFailure) = $0, attemptFailure.error as NSError == defaultError {
                    expectation.fulfill()
                }
            })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    func test_attempt_success_received() {
        let retrier = buildRetrier(immediateSuccessJob)
        let expectation = expectation(description: "Success received")
        let cancellable = retrier
            .publisher()
            .sink(receiveCompletion: { _ in }, receiveValue: {
                if case .attemptSuccess = $0 {
                    expectation.fulfill()
                }
            })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    func test_retries() {
        var calledOnce = false
        let retrier = buildRetrier({
            if !calledOnce {
                calledOnce = true
                throw defaultError
            }
        })
        let successExpectation = expectation(description: "Success received")
        var failureReceived = false
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: { _ in },
                  receiveValue: {
                switch $0 {
                case .attemptSuccess:
                    guard failureReceived else {
                        XCTFail("Should have received failure before success")
                        return
                    }
                    successExpectation.fulfill()
                case .attemptFailure:
                    failureReceived = true
                default:
                    break
                }
            })
        waitForExpectations(timeout: defaultSequenceWaitingTime)
        cancellable.cancel()
    }

    func test_job_not_called_on_immediate_cancellation() {
        let retrier = buildRetrier({
            XCTFail("Should not be called on immediate cancellation")
        })
        retrier.cancel()
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: defaultSequenceWaitingTime)
    }

    func test_proper_event_received_after_immediate_cancellation() {
        let retrier = buildRetrier(immediateSuccessJob)
        let completionExpectation = expectation(description: "Completion with CancellationError received")
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: { _ in },
                  receiveValue: {
                switch $0 {
                case .attemptSuccess, .attemptFailure:
                    XCTFail("Should not receive attempt event on immediate cancellation")
                case .completion(let error):
                    if let error, error is CancellationError {
                        completionExpectation.fulfill()
                    } else {
                        XCTFail("Improper completion received, expected cancellation error")
                    }
                }
            })
        retrier.cancel()
        wait(for: [completionExpectation], timeout: 0)
        cancellable.cancel()
    }

    func test_finished_received_after_cancellation() {
        let failureExpectation = expectation(description: "Failure received")
        let retrier = buildRetrier(immediateSuccessJob)
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: {
                if case .finished = $0 {
                    failureExpectation.fulfill()
                }
            },
                  receiveValue: { _ in })
        retrier.cancel()
        waitForExpectations(timeout: 0)
        cancellable.cancel()
    }

    @MainActor
    func test_deallocated_some_time_after_cancellation() async throws {
        weak var retrier = retrier(immediateFailureJob)
        retrier?.cancel()
        try await taskWait()
        XCTAssertNil(retrier)
    }

    @MainActor
    func test_still_trying_while_not_finished_and_not_retained() async throws {
        var shouldSignalExecution = false
        var executed = false
        weak var retrier = retrier {
            if shouldSignalExecution {
                executed = true
            }
            throw defaultError
        }
        try await taskWait()
        shouldSignalExecution = true
        try await taskWait(defaultSequenceWaitingTime / 2)
        XCTAssertTrue(executed)
        retrier?.cancel()
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == RetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
