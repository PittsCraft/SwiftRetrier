import XCTest
@testable import SwiftRetrier
import Combine

class SingleOutputConditionalRetrierTests<R: SingleOutputRetrier>: XCTestCase {

    var retrier: ((AnyPublisher<Bool, Never>, Job<Void>) -> R)!

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
    func test_error_thrown_when_condition_publisher_completes_with_no_value() async {
        let condition = Empty<Bool, Never>().eraseToAnyPublisher()
        let retrier = buildRetrier(condition, immediateSuccessJob)
        do {
            _ = try await retrier.value
            XCTFail("Retrier should throw when the conditionPublisher completes with no value")
        } catch {}
    }

    @MainActor
    func test_error_thrown_when_condition_publisher_completes_after_false() async {
        let condition = Just(false)
            .eraseToAnyPublisher()
        let retrier = buildRetrier(condition, immediateSuccessJob)
        do {
            _ = try await retrier.value
            XCTFail("Retrier should throw when the conditionPublisher completes after emitting false")
        } catch {}
    }

    func test_receive_second_trial_async_value() {
        let job = {
            try await taskWait()
        }
        let retrier = buildRetrier(trueFalseTruePublisher(), job)
        let expectation = expectation(description: "Receive async output")
        Task {
            _ = try await retrier.value
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultSequenceWaitingTime)
    }

    @MainActor
    func test_receive_publisher_completion_after_second_trial_finished() async {
        let job = {
            try await taskWait()
        }
        let expectation = expectation(description: "Finished")

        let retrier = buildRetrier(trueFalseTruePublisher(), job)
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: {
                if case .finished = $0 {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        await fulfillment(of: [expectation], timeout: defaultSequenceWaitingTime)
        cancellable.cancel()
    }

    func test_right_attempts_count() {
        var failedOnce = false
        var jobExecutionCount = 0
        let job = {
            jobExecutionCount += 1
            try await taskWait()
            if !failedOnce {
                failedOnce = true
                throw defaultError
            }
        }
        let completionReceived = expectation(description: "Completion received")

        let retrier = buildRetrier(trueFalseTruePublisher(), job)
        let cancellable = retrier.publisher()
            .sink(receiveCompletion: { _ in
                completionReceived.fulfill()
            },
                  receiveValue: { _ in })
        wait(for: [completionReceived], timeout: defaultSequenceWaitingTime)
        // First attempt should be canceled by condition
        // Second attempt should throw
        // Third attempt should succeed
        XCTAssertEqual(jobExecutionCount, 3, "Job should be attempted three times among the two trials")
        cancellable.cancel()
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == SingleOutputConditionalRetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
