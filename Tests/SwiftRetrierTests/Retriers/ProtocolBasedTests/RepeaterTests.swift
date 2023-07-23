import Foundation
import XCTest
@testable import SwiftRetrier

class RepeaterTests<R: Repeater>: XCTestCase {
    var retrier: ((TimeInterval, @escaping Job<Void>) -> R)!

    private let successJob: () -> Void = {}
    private let failureJob: () throws -> Void = { throw nsError }

    private var instance: R?

    func buildRetrier(_ repeatDelay: TimeInterval, _ job: @escaping Job<Void>) -> R {
        let retrier = retrier(repeatDelay, job)
        instance = retrier
        return retrier
    }

    override func tearDown() {
        instance?.cancel()
        instance = nil
        super.tearDown()
    }

    func test_repeats() {
        var count = 0
        let expectation = expectation(description: "Should repeat")
        _ = buildRetrier(0.05, {
            count += 1
            if count == 3 {
                expectation.fulfill()
            }
        })
        waitForExpectations(timeout: 0.2)
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == RepeaterTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
