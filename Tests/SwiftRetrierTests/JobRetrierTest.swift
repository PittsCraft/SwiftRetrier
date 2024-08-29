import XCTest
@testable import SwiftRetrier
@preconcurrency import Combine

final class JobRetrierTest: XCTestCase {

    func sameEvents<T: Equatable>(_ event1: RetrierEvent<T>, _ event2: RetrierEvent<T>) -> Bool {
        switch (event1, event2) {
        case (.attemptSuccess(let value1), .attemptSuccess(let value2)):
            value1 == value2
        case (.attemptFailure(let failure1), .attemptFailure(let failure2)):
            failure1.index == failure2.index && (failure1.error as? TestError) == (failure2.error as? TestError)
        case (.completion(let error1), .completion(let error2)):
            (error1 == nil) && (error2 == nil) || (error1 as? TestError) == (error2 as? TestError)
        default:
            false
        }
    }

    func assertSameSequence<T: Equatable>(_ sequence1: [RetrierEvent<T>], _ sequence2: [RetrierEvent<T>]) {
        XCTAssertEqual(sequence1.count, sequence2.count, "Events count differs from expected one")
        XCTAssertTrue(zip(sequence1, sequence2).allSatisfy { sameEvents($0, $1) }, "Events should be the same")
    }

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
}
