import Foundation
import XCTest
@testable import SwiftRetrier

// swiftlint:disable type_name
class SimpleInfallibleRetrier_RetrierTests: RetrierTests<SimpleInfallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleInfallibleRetrier(policy: .constantBackoff(delay: 0.1), job: $0)
        }
    }
}

class SimpleInfallibleRetrier_SingleOutputRetrierTests: SingleOutputRetrierTests<SimpleInfallibleRetrier<Void>> {
    override func setUp() {
        retrier = {
            SimpleInfallibleRetrier(policy: .constantBackoff(delay: 0.1), job: $0)
        }
    }
}
// swiftlint:enable type_name
