import XCTest
@testable import SwiftRetrier
@preconcurrency import Combine

final class JobRepeaterTest: XCTestCase {

    func test_When_jobSucceeds_Should_repeatAfterDelay() {
        let repeatDelay = 0.2
        let repeater = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: repeatDelay,
            conditionPublisher: nil,
            job: { true }
        )
        let success = CurrentValueSubject<Int, Never>(0)
        let expectation = expectation(description: "Got at least two success")
        let startDate = Date()
        let subscription = repeater
            .sink { _ in
                success.value += 1
                if success.value == 2 {
                    expectation.fulfill()
                }
            }
        wait(for: [expectation], timeout: defaultTimeout)
        XCTAssertGreaterThanOrEqual(
            Date(),
            startDate.addingTimeInterval(repeatDelay),
            "Expecting second job to be executed after at least repeat delay"
        )
        subscription.cancel()
    }

    @MainActor
    func test_When_repeaterCancelled_Should_stopRepeating() async throws {
        let cancelled = CurrentValueSubject<Bool, Never>(false)
        let repeater = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: nil,
            job: { @MainActor [cancelled] in
                XCTAssert(!cancelled.value, "Job executed after cancellation")
                cancelled.value = true
            }
        )
        let subscription = repeater
            .sink { _ in }
        let cancelSubscription = cancelled.sink {
            if $0 { subscription.cancel() }
        }
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * 0.5))
        subscription.cancel()
        cancelSubscription.cancel()
    }

    @MainActor
    func test_When_repeaterCancelled_Should_interruptJob() async throws {
        let expectation = expectation(description: "Job was cancelled")
        let subscription = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: nil,
            job: {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * 10)
                } catch {
                    if error is CancellationError {
                        expectation.fulfill()
                    }
                }
            }
        ).sink { _ in }
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * 0.5))
        subscription.cancel()
        await fulfillment(of: [expectation], timeout: defaultTimeout)
    }

    @MainActor
    func test_When_succeeding_Should_getOnlyAttemptSuccess() async throws {
        let expectation = expectation(description: "Got 10 events")
        var sequence = [RetrierEvent<Bool>]()
        let subscription = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: nil,
            job: { true }
        ).sink {
            sequence.append($0)
            if sequence.count == 10 {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: defaultTimeout)
        subscription.cancel()
        XCTAssertTrue(
            sequence.allSatisfy {
                if case .attemptSuccess = $0 {
                    true
                } else {
                    false
                }
            }, "All events should be attempt successes"
        )
    }

    @MainActor
    func test_When_conditionFalse_Should_notExecuteJob() async throws {
        let subscription = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: Empty(completeImmediately: false).prepend(false).eraseToAnyPublisher(),
            job: {
                XCTFail("Job should not be executed")
            }
        ).sink { _ in }
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * 0.5))
        subscription.cancel()
    }

    
}
