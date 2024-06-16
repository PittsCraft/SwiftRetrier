import Foundation
import XCTest
@testable import SwiftRetrier

class SingleOutputFallibleRetrierTests<R: SingleOutputRetrier>: XCTestCase {
    var retrier: ((RetryPolicy, @escaping Job<Void>) -> R)!

    private var instance: R?

    func buildRetrier(_ policy: RetryPolicy, _ job: @escaping Job<Void>) -> R {
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
    func test_Should_ThrowErrorOnValueAwaiting_When_PolicyGivesUp() async {
        let retrier = buildRetrier(Policy.testDefault().giveUpAfter(maxAttempts: 1), immediateFailureJob)
        do {
            _ = try await retrier.value
            XCTFail("Unexpected success")
        } catch {}
    }

    @MainActor
    func test_Should_ReceiveFinishedCompletionOnFailurePublisher_When_RetrierSucceedsOnLastAttempt() {
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

    @MainActor
    func test_Should_ReceiveAttemptFailureOnFailurePublisher_When_JobFailsOnLastAttempt() {
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
