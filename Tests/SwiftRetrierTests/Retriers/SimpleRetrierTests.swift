import XCTest
@testable import SwiftRetrier
import Combine

// swiftlint:disable type_name
class SimpleRetrier_RetrierTests: RetrierTests<SimpleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleRetrier(policy: Policy.testDefault(), job: $0)
        }
    }
}

class SimpleRetrier_FallibleRetrierTests: FallibleRetrierTests<SimpleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleRetrier(policy: $0, job: $1)
        }
    }
}

class SimpleRetrier_SingleOutputRetrierTests: SingleOutputRetrierTests<SimpleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleRetrier(policy: Policy.testDefault(), job: $0)
        }
    }
}

class SimpleRetrier_SingleOutputFallibleRetrierTests:
    SingleOutputFallibleRetrierTests<SimpleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleRetrier(policy: $0, job: $1)
        }
    }
}
// swiftlint:enable type_name
