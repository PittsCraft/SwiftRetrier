import XCTest
@testable import SwiftRetrier
import Combine

// swiftlint:disable type_name
class ConditionalRetrier_RetrierTests: RetrierTests<ConditionalRetrier<Void>> {
    override func setUp() {
        self.retrier = {
            ConditionalRetrier(policy: Policy.testDefault(),
                               conditionPublisher: Just(true),
                               job: $0)
        }
    }
}

class ConditionalRetrier_FallibleRetrierTests: FallibleRetrierTests<ConditionalRetrier<Void>> {
    override func setUp() {
        self.retrier = {
            ConditionalRetrier(policy: $0, conditionPublisher: Just(true), job: $1)
        }
    }
}

class ConditionalRetrier_SingleOutputRetrierTests: SingleOutputRetrierTests<ConditionalRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalRetrier(policy: Policy.testDefault(),
                               conditionPublisher: Just(true),
                               job: $0)
        }
    }
}

class ConditionalRetrier_SingleOutputFallibleRetrierTests:
    SingleOutputFallibleRetrierTests<ConditionalRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalRetrier(policy: $0, conditionPublisher: Just(true), job: $1)
        }
    }
}

class ConditionalRetrier_ConditionalRetrierTests: ConditionalRetrierTests<ConditionalRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalRetrier(policy: Policy.testDefault(),
                               conditionPublisher: $0,
                               job: $1)
        }
    }
}
// swiftlint:enable type_name
