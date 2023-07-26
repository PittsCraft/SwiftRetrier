import XCTest
@testable import SwiftRetrier
import Combine

// swiftlint:disable type_name
class ConditionalInfallibleRetrier_RetrierTests: RetrierTests<ConditionalInfallibleRetrier<Void>> {
    override func setUp() {
        self.retrier = {
            ConditionalInfallibleRetrier(policy: Policy.testDefault(), conditionPublisher: Just(true), job: $0)
        }
    }
}

class ConditionalInfallibleRetrier_SingleOutputRetrierTests:
    SingleOutputRetrierTests<ConditionalInfallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalInfallibleRetrier(policy: Policy.testDefault(), conditionPublisher: Just(true), job: $0)
        }
    }
}

class ConditionalInfallibleRetrier_ConditionalRetrierTests:
    ConditionalRetrierTests<ConditionalInfallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalInfallibleRetrier(policy: Policy.testDefault(), conditionPublisher: $0, job: $1)
        }
    }
}
// swiftlint:enable type_name
