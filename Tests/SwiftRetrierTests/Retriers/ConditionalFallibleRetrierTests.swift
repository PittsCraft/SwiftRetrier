import XCTest
@testable import SwiftRetrier
import Combine

// swiftlint:disable type_name
class ConditionalFallibleRetrier_RetrierTests: RetrierTests<ConditionalFallibleRetrier<Void>> {
    override func setUp() {
        self.retrier = {
            ConditionalFallibleRetrier(policy: .testDefault(),
                                       conditionPublisher: Just(true),
                                       job: $0)
        }
    }
}

class ConditionalFallibleRetrier_FallibleRetrierTests: FallibleRetrierTests<ConditionalFallibleRetrier<Void>> {
    override func setUp() {
        self.retrier = {
            ConditionalFallibleRetrier(policy: $0, conditionPublisher: Just(true), job: $1)
        }
    }
}

class ConditionalFallibleRetrier_SingleOutputRetrierTests: SingleOutputRetrierTests<ConditionalFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalFallibleRetrier(policy: .testDefault(),
                                       conditionPublisher: Just(true),
                                       job: $0)
        }
    }
}

class ConditionalFallibleRetrier_SingleOutputFallibleRetrierTests:
    SingleOutputFallibleRetrierTests<ConditionalFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalFallibleRetrier(policy: $0, conditionPublisher: Just(true), job: $1)
        }
    }
}

class ConditionalFallibleRetrier_ConditionalRetrierTests: ConditionalRetrierTests<ConditionalFallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalFallibleRetrier(policy: .testDefault(),
                                       conditionPublisher: $0,
                                       job: $1)
        }
    }
}
// swiftlint:enable type_name
