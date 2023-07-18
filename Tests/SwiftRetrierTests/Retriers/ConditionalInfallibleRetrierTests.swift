import XCTest
@testable import SwiftRetrier
import Combine

class ConditionalInfallibleRetrier_RetrierTests: RetrierTests<ConditionalInfallibleRetrier<Void>> {
    override func setUp() {
        self.retrier = {
            ConditionalInfallibleRetrier(policy: .constantBackoff(delay: 0.1), conditionPublisher: Just(true), job: $0)
        }
    }
}


class ConditionalInfallibleRetrier_SingleOutputRetrierTests: SingleOutputRetrierTests<ConditionalInfallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalInfallibleRetrier(policy: .constantBackoff(delay: 0.1), conditionPublisher: Just(true), job: $0)
        }
    }
}

class ConditionalInfallibleRetrier_ConditionalRetrierTests: ConditionalRetrierTests<ConditionalInfallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            ConditionalInfallibleRetrier(policy: .constantBackoff(delay: 0.1), conditionPublisher: $0, job: $1)
        }
    }
}
