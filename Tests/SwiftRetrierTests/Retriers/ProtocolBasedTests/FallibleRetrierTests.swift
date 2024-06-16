import Foundation
import XCTest
@testable import SwiftRetrier

class FallibleRetrierTests<R: Retrier>: XCTestCase {

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
    func test_Should_PublishCompletionEventWithError_When_JobFailsAndPolicyGivesUp() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        let expectation = expectation(description: "Failure completion received")
        let cancellable = retrier
            .publisher()
            .sink { event in
                if case .completion(let error) = event, error != nil {
                    expectation.fulfill()
                }
            }
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    @MainActor
    func test_Should_CompleteSuccessPublisher_When_JobFailsAndPolicyGivesUp() {
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), immediateFailureJob)
        let expectation = expectation(description: "Completion received")
        let cancellable = retrier
            .successPublisher()
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { _ in })
        waitForExpectations(timeout: defaultWaitingTime)
        cancellable.cancel()
    }

    @MainActor
    func test_Should_ThrowErrorInJob_When_RetrierIsCancelled() {
        let cancellationExpectation = expectation(description: "Cancellation catched")
        var fulfilled = false
        let retrier = buildRetrier(Policy.testDefault(maxAttempts: 1), { @MainActor in
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

    @MainActor
    func test_Should_DeallocateRetrier_When_RetrierHasCompletedWithFailureSomeTimeAgo() async throws {
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
