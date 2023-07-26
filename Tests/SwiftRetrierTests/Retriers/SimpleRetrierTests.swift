import XCTest
@testable import SwiftRetrier
import Combine

// swiftlint:disable type_name
class SimpleFallibleRetrier_RetrierTests: RetrierTests<SimpleFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleFallibleRetrier(policy: Policy.testDefault(), job: $0)
        }
    }
}

class SimpleFallibleRetrier_FallibleRetrierTests: FallibleRetrierTests<SimpleFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleFallibleRetrier(policy: $0, job: $1)
        }
    }
}

class SimpleFallibleRetrier_SingleOutputRetrierTests: SingleOutputRetrierTests<SimpleFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleFallibleRetrier(policy: Policy.testDefault(), job: $0)
        }
    }
}

class SimpleFallibleRetrier_SingleOutputFallibleRetrierTests:
    SingleOutputFallibleRetrierTests<SimpleFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleFallibleRetrier(policy: $0, job: $1)
        }
    }
}
// swiftlint:enable type_name
