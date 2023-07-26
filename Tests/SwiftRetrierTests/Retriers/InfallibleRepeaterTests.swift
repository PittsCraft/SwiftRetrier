import Foundation
import XCTest
@testable import SwiftRetrier

// swiftlint:disable type_name
class InfallibleRepeater_RetrierTests: RetrierTests<InfallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            InfallibleRepeater(policy: Policy.testDefault(), repeatDelay: 100, job: $0)
        }
    }
}

class InfallibleRepeater_RepeaterTests: RepeaterTests<InfallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            InfallibleRepeater(policy: Policy.testDefault(), repeatDelay: $0, job: $1)
        }
    }
}
// swiftlint:enable type_name
