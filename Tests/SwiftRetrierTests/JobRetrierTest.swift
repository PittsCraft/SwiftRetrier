import XCTest
@testable import SwiftRetrier
@preconcurrency import Combine

final class JobRetrierTest: XCTestCase {

    func test_When_jobSuceeds_Should_completeProperly() {
        let expectedSequence: [RetrierEvent<Bool>] = [
            .attemptSuccess(true),
            .completion(nil)
        ]
        var sequence = [RetrierEvent<Bool>]()
        let expectation = expectation(description: "Publisher finishes")
        let cancellable = JobRetrier(policy: ExponentialBackoffRetryPolicy(), conditionPublisher: nil, job: { true })
            .handleEvents(receiveCompletion: { _ in
                expectation.fulfill()
            })
            .sink {
                sequence.append($0)
            }
        wait(for: [expectation], timeout: defaultTimeout)
        assertSameSequence(expectedSequence, sequence)
        cancellable.cancel()
    }

    func test_When_jobFailsPolicyGivesUp_Should_completeProperly() {
        let expectedSequence: [RetrierEvent<Bool>] = [
            .attemptFailure(.init(trialStart: Date(), index: 0, error: TestError())),
            .completion(TestError())
        ]
        var sequence = [RetrierEvent<Bool>]()
        let expectation = expectation(description: "Publisher finishes")
        let cancellable = JobRetrier(
            policy: ConstantDelayRetryPolicy().giveUp(on: { _, _ in true }),
            conditionPublisher: nil,
            job: { throw TestError() }
        )
            .handleEvents(receiveCompletion: { _ in
                expectation.fulfill()
            })
            .sink {
                sequence.append($0)
            }
        wait(for: [expectation], timeout: defaultTimeout)
        assertSameSequence(expectedSequence, sequence)
        cancellable.cancel()
    }

    func test_When_jobFailsFirstTime_Should_retry() {
        let expectedSequence: [RetrierEvent<Bool>] = [
            .attemptFailure(.init(trialStart: Date(), index: 0, error: TestError())),
            .attemptSuccess(true),
            .completion(nil)
        ]
        var sequence = [RetrierEvent<Bool>]()
        let expectation = expectation(description: "Publisher finishes")
        let didFailOnce = CurrentValueSubject<Bool, Never>(false)
        let cancellable = JobRetrier(
            policy: ConstantDelayRetryPolicy(delay: 0),
            conditionPublisher: nil,
            job: { [didFailOnce] in
                if didFailOnce.value {
                    true
                } else {
                    didFailOnce.value = true
                    throw TestError()
                }
            }
        )
            .handleEvents(receiveCompletion: { _ in
                expectation.fulfill()
            })
            .sink {
                sequence.append($0)
            }
        wait(for: [expectation], timeout: defaultTimeout)
        assertSameSequence(expectedSequence, sequence)
        cancellable.cancel()
    }

    @MainActor
    func test_When_retrierCancelled_Should_interruptJob() async throws {
        let expectation = expectation(description: "Job was cancelled")
        let subscription = JobRetrier(
            policy: ConstantDelayRetryPolicy(delay: 0),
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
    func test_When_conditionFalse_Should_notExecuteJob() async throws {
        let subscription = JobRetrier(
            policy: ConstantDelayRetryPolicy(delay: 0),
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
        let subscription = JobRetrier(
            policy: ConstantDelayRetryPolicy(delay: 0),
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
    func test_When_conditionCompletesAfterTrue_Should_receiveSuccessAndCompleteEventThenCompletes() async throws {
        let expectation = expectation(description: "Publisher finished")
        var sequence = [RetrierEvent<Bool>]()
        let expectedSequence: [RetrierEvent<Bool>] = [
            .attemptSuccess(true),
            .completion(nil)
        ]

        let subscription = JobRetrier(
            policy: ConstantDelayRetryPolicy(delay: 0),
            conditionPublisher: Just(true).eraseToAnyPublisher(),
            job: { true }
        ).sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                expectation.fulfill()
            case .failure:
                XCTFail("Unexpected failure")
            }
        }, receiveValue: {
            sequence.append($0)
        })
        await fulfillment(of: [expectation], timeout: defaultTimeout)
        assertSameSequence(expectedSequence, sequence)
        subscription.cancel()
    }
}
