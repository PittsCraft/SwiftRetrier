import Foundation
import XCTest
@testable import SwiftRetrier

// swiftlint:disable type_name
class Repeater_RetrierTests: RetrierTests<SimpleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            SimpleRepeater(policy: Policy.testDefault(), repeatDelay: 100, job: $0)
        }
    }
}

class Repeater_FallibleRetrierTests: FallibleRetrierTests<SimpleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            SimpleRepeater(policy: $0, repeatDelay: 100, job: $1)
        }
    }
}

class Repeater_RepeaterTests: RepeaterTests<SimpleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            SimpleRepeater(policy: Policy.testDefault(), repeatDelay: $0, job: $1)
        }
    }
}
// swiftlint:enable type_name
