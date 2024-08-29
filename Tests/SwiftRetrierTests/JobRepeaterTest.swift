import XCTest
@testable import SwiftRetrier
@preconcurrency import Combine

final class JobRepeaterTest: XCTestCase {

    func test_When_jobSucceeds_Should_repeatAfterDelay() {
        let repeater = JobRepeater(
            policy: ConstantDelayRetryPolicy(delay: 0),
            repeatDelay: 0,
            conditionPublisher: nil,
            job: { true }
        )
        let success = CurrentValueSubject<Int, Never>(0)
        let expectation = expectation(description: "Got at least two success")
        let subscription = repeater
            .sink { _ in
                success.value += 1
                if success.value == 2 {
                    expectation.fulfill()
                }
            }
        wait(for: [expectation], timeout: defaultTimeout)
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
}
