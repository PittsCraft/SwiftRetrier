import Foundation
import XCTest
@testable import SwiftRetrier

class RetrierTests<R: Retrier>: XCTestCase {

    var retrier: ((@escaping Job<Void>) -> R)!

    private let successJob: () -> Void = {}
    private let failureJob: () throws -> Void = { throw NSError() }

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
        let ownError = NSError(domain: "Domain", code: 0)
        let retrier = buildRetrier({ throw ownError })
        let expectation = expectation(description: "Failure received")
        let cancellable = retrier
            .attemptPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: {
                if case .failure(let error) = $0, error as NSError == ownError {
                    expectation.fulfill()
                }
            })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_attempt_success_received() {
        let retrier = buildRetrier(successJob)
        let expectation = expectation(description: "Success received")
        let cancellable = retrier
            .attemptPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: {
                if case .success = $0 {
                    expectation.fulfill()
                }
            })
        waitForExpectations(timeout: 0.1)
        cancellable.cancel()
    }

    func test_retries() {
        var calledOnce = false
        let retrier = buildRetrier({
            if !calledOnce {
                calledOnce = true
                throw NSError()
            }
        })
        let successExpectation = expectation(description: "Success received")
        var failureReceived = false
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: {
                switch $0 {
                case .success:
                    guard failureReceived else {
                        XCTFail("Should have received failure before success")
                        return
                    }
                    successExpectation.fulfill()
                case .failure:
                    failureReceived = true
                }
            })
        waitForExpectations(timeout: 1)
        cancellable.cancel()
    }

    func test_job_not_called_on_immediate_cancellation() {
        let retrier = buildRetrier({
            XCTFail("Should not be called on immediate cancellation")
        })
        retrier.cancel()
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: 0.2)
    }

    func test_no_value_received_after_immediate_cancellation() {
        let retrier = buildRetrier(successJob)
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in
                XCTFail("Should not receive value on immediate cancellation")
            })
        retrier.cancel()
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for some time")], timeout: 0.2)
        cancellable.cancel()
    }

    func test_finished_received_after_cancellation() {
        let failureExpectation = expectation(description: "Failure received")
        let retrier = buildRetrier(successJob)
        let cancellable = retrier.attemptPublisher
            .sink(receiveCompletion: {
                if case .finished = $0 {
                    failureExpectation.fulfill()
                }
            },
                  receiveValue: { _ in
                XCTFail("Should not receive value on immediate cancellation")
            })
        retrier.cancel()
        waitForExpectations(timeout: 0)
        cancellable.cancel()
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == RetrierTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
