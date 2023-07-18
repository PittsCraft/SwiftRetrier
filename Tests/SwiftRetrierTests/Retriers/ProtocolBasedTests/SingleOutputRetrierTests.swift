import Foundation
import XCTest
@testable import SwiftRetrier

class SingleOutputRetrierTests<R: SingleOutputRetrier>: XCTestCase {
    var retrier: ((@escaping Job<Void>) -> R)!

    let successJob: Job<Void> = {}
    let failureJob: Job<Void> = { throw NSError() }

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

    func test_publisher_finished_received_on_success() {
        let retrier = buildRetrier(successJob)
        let expectation = expectation(description: "Finished received")
        let cancellable = retrier
            .attemptPublisher
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_success_publisher_finished_received_on_success() {
        let retrier = buildRetrier(successJob)
        let expectation = expectation(description: "Finished received")
        let cancellable = retrier
            .attemptSuccessPublisher
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_finishes_after_retry() {
        var calledOnce = false
        let retrier = buildRetrier({
            if !calledOnce {
                calledOnce = true
                throw NSError()
            }
        })
        let expectation = expectation(description: "Completes")
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: {
                if case .finished = $0 {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
        waitForExpectations(timeout: 0.3)
        cancellable.cancel()
    }

    func test_async_value_received_after_retry() {
        var calledOnce = false
        let retrier = buildRetrier({
            if !calledOnce {
                calledOnce = true
                throw NSError()
            }
        })
        let expectation = expectation(description: "Got async value")
        Task {
            _ = try await retrier.value
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.3)
    }

    @MainActor
    func test_await_value_throws_on_cancellation() async {
        let expectation = expectation(description: "Cancellation catched")
        let retrier = buildRetrier({
            do {
                try await Task.sleep(nanoseconds: nanoseconds(0.1))
            } catch {
                expectation.fulfill()
                throw error
            }
        })
        do {
            try await Task.sleep(nanoseconds: nanoseconds(0.05))
        } catch {}
        retrier.cancel()
        do {
            _ = try await retrier.value
            XCTFail("Unexpected success")
        } catch {}
        await fulfillment(of: [expectation], timeout: 0.2)
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == SingleOutputRetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
