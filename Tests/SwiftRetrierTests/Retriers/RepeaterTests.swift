import Foundation
import XCTest
@testable import SwiftRetrier

// swiftlint:disable type_name
class Repeater_RetrierTests: RetrierTests<Repeater<Void>> {
    override func setUp() {
        self.retrier = {
            Repeater(policy: Policy.testDefault(), repeatDelay: 100, job: $0)
        }
    }
}

class Repeater_FallibleRetrierTests: FallibleRetrierTests<Repeater<Void>> {
    override func setUp() {
        self.retrier = {
            Repeater(policy: $0, repeatDelay: 100, job: $1)
        }
    }
}

class RepeaterTests: XCTestCase {
    var retrier: ((TimeInterval, @escaping Job<Void>) -> Repeater<Void>)!

    private var instance: Repeater<Void>?

    func buildRetrier(_ repeatDelay: TimeInterval, _ job: @escaping Job<Void>) -> Repeater<Void> {
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
        _ = buildRetrier(repeatDelay, {
            count += 1
            if count == 3 {
                expectation.fulfill()
            }
        })
        waitForExpectations(timeout: defaultSequenceWaitingTime)
    }

    override class var defaultTestSuite: XCTestSuite {
        if self == RepeaterTests.self {
            return XCTestSuite(name: "Empty suite")
        } else {
            return super.defaultTestSuite
        }
    }
}
// swiftlint:enable type_name
