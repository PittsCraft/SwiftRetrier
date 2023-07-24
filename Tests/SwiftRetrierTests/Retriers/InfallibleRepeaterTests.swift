import Foundation
import XCTest
@testable import SwiftRetrier

// swiftlint:disable type_name
class InfallibleRepeater_RetrierTests: RetrierTests<InfallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            InfallibleRepeater(repeatDelay: 100, policy: .testDefault(), job: $0)
        }
    }
}

class InfallibleRepeater_RepeaterTests: RepeaterTests<InfallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            InfallibleRepeater(repeatDelay: $0, policy: .testDefault(), job: $1)
        }
    }
}
// swiftlint:enable type_name
