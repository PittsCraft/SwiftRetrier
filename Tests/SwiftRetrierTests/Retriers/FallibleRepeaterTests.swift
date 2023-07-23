import Foundation
import XCTest
@testable import SwiftRetrier

// swiftlint:disable type_name
class FallibleRepeater_RetrierTests: RetrierTests<FallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            FallibleRepeater(repeatDelay: 100, policy: .constantBackoff(delay: 0.1), job: $0)
        }
    }
}

class FallibleRepeater_FallibleRetrierTests: FallibleRetrierTests<FallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            FallibleRepeater(repeatDelay: 100, policy: $0, job: $1)
        }
    }
}

class FallibleRepeater_RepeaterTests: RepeaterTests<FallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            FallibleRepeater(repeatDelay: $0, policy: .constantBackoff(delay: 0.1), job: $1)
        }
    }
}
// swiftlint:enable type_name
