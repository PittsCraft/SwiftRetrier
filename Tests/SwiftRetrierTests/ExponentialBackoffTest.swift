import XCTest
@testable import SwiftRetrier
@preconcurrency import Combine

final class ExponentialBackoffTest: XCTestCase {

    func test_When_exponentationGoesUp_Then_noOverflow() {
        let policy = ExponentialBackoffRetryPolicy()
        _ = policy.retryDelay(for: AttemptFailure(trialStart: Date(), index: .max, error: TestError()))
    }
}
