import Foundation
import XCTest
import Combine
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

    @MainActor
    func test_Should_PublishAttemptFailureWithJobError_When_JobFails() {
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

    @MainActor
    func test_Should_PublishAttemptSuccess_When_JobSucceeds() {
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

    @MainActor
    func test_Should_PublishAttemptFailureThenAttemptSuccess_When_JobFailsThenSucceeds() {
        var calledOnce = false
        let retrier = buildRetrier({ @MainActor in
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

    func test_Should_NotExecuteJob_When_RetrierIsCancelledInTheSameCycleItIsCreated() {
        let retrier = buildRetrier({
            XCTFail("Should not be called on immediate cancellation")
        })
        retrier.cancel()
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: defaultSequenceWaitingTime)
    }

    func test_Should_PublishCompletionWithCancellationError_When_RetrierIsCancelledInTheSameCycleItIsCreated() {
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

    @MainActor
    func test_Should_CompletePublisherWithFinished_When_RetrierIsCancelled() {
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
    func test_Should_DeallocateRetrier_When_RetrierWasCancelledSomeTimeAgo() async throws {
        weak var retrier = retrier(immediateFailureJob)
        retrier?.cancel()
        try await taskWait()
        XCTAssertNil(retrier)
    }

    @MainActor
    func test_Should_StillRetry_When_RetrierNotFinishedAndNotRetained() async throws {
        // Just working around capture issue
        let shouldSignalExecution = CurrentValueSubject<Bool, Never>(false)
        var executed = false
        weak var retrier = retrier { @MainActor in
            if shouldSignalExecution.value {
                executed = true
            }
            throw defaultError
        }
        try await taskWait()
        shouldSignalExecution.value = true
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
