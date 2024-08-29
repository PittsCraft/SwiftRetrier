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

    func test_When_conditionCompletesAfterFalse_Should_completePublisher() {
        let completed = CurrentValueSubject<Bool, Never>(false)
        let subscription = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: Just(false).eraseToAnyPublisher(),
            job: {
                XCTFail("Job should not be executed")
            }
        ).sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                completed.value = true
            case .failure:
                XCTFail("Unexpected failure")
            }
        }, receiveValue: { event in
            XCTFail("Unexpected event \(event)")
        })
        XCTAssertTrue(completed.value)
        subscription.cancel()
    }

    @MainActor
    func test_When_conditionCompletesAfterTrue_Should_receiveMultipleSuccessNoCompletion() async throws {
        let expectation = expectation(description: "Received at least 10 successes")
        let count = CurrentValueSubject<Int, Never>(0)
        let subscription = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: Just(true).eraseToAnyPublisher(),
            job: { true }
        ).sink(receiveCompletion: { completion in
            XCTFail("Unexpected completion")
        }, receiveValue: {
            switch $0 {
            case .attemptSuccess:
                count.value += 1
                if count.value == 10 {
                    expectation.fulfill()
                }
            default:
                XCTFail("Unexpected event received \($0)")
            }
        })
        await fulfillment(of: [expectation], timeout: 1000)
        subscription.cancel()
    }
}
