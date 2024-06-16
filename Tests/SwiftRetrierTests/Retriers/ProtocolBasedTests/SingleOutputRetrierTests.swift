import Foundation
import XCTest
@testable import SwiftRetrier

class SingleOutputRetrierTests<R: SingleOutputRetrier>: XCTestCase {
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
    func test_Should_CompletePublisherWithFinished_When_JobSucceeds() {
        let retrier = buildRetrier(immediateSuccessJob)
        let expectation = expectation(description: "Finished received")
        let cancellable = retrier
            .publisher()
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    @MainActor
    func test_Should_CompleteSuccessPublisherWithFinished_When_JobSucceeds() {
        let retrier = buildRetrier(immediateSuccessJob)
        let expectation = expectation(description: "Finished received")
        let cancellable = retrier
            .successPublisher()
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    @MainActor
    func test_Should_CompletePublisherWithFinished_When_JobSucceedsAfterOneRetry() {
        var calledOnce = false
        let retrier = buildRetrier({ @MainActor in
            if !calledOnce {
                calledOnce = true
                throw defaultError
            }
        })
        let expectation = expectation(description: "Completes")
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: {
                if case .finished = $0 {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultSequenceWaitingTime)
        cancellable.cancel()
    }

    @MainActor
    func test_Should_ReceiveAsyncValue_When_JobSucceedsAfterOneRetry() {
        var calledOnce = false
        let retrier = buildRetrier({ @MainActor in
            if !calledOnce {
                calledOnce = true
                throw defaultError
            }
        })
        let expectation = expectation(description: "Got async value")
        Task {
            _ = try await retrier.value
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultSequenceWaitingTime)
    }

    @MainActor
    func test_Should_ThrowErrorInJobAndInValueAwaiting_When_RetrierIsCancelled() async throws {
        let expectation = expectation(description: "Cancellation catched")
        let retrier = buildRetrier({
            do {
                try await taskWait(defaultJobDuration)
            } catch {
                expectation.fulfill()
                throw error
            }
        })
        try await taskWait(defaultJobDuration / 4)
        retrier.cancel()
        do {
            _ = try await retrier.value
            XCTFail("Unexpected success")
        } catch {}
        await fulfillment(of: [expectation], timeout: defaultJobDuration * 2)
    }

    @MainActor
    func test_Should_SucceedValueAwaiting_When_AwaitStartedAfterRetrierSuccessfulResolution() async throws {
        let retrier = buildRetrier(immediateSuccessJob)
        // Let the retrier finish
        try await taskWait()
        let expectation = expectation(description: "Value await resolved")
        Task {
            _ = try await retrier.value
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: defaultSequenceWaitingTime)
    }

    @MainActor
    func test_Should_DeallocateRetrierAfterSomeTime_When_RetrierSuccessfullyFinished() async throws {
        weak var retrier = retrier(immediateSuccessJob)
        try await taskWait()
        XCTAssertNil(retrier)
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == SingleOutputRetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
