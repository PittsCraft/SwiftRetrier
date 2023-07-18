import Foundation
import XCTest
@testable import SwiftRetrier

class InfallibleRepeater_RetrierTests: RetrierTests<InfallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            InfallibleRepeater(repeatDelay: 100, policy: .constantBackoff(delay: 0.1), job: $0)
        }
    }
}

class InfallibleRepeater_RepeaterTests: RepeaterTests<InfallibleRepeater<Void>> {
    override func setUp() {
        self.retrier = {
            InfallibleRepeater(repeatDelay: $0, policy: .constantBackoff(delay: 0.1), job: $1)
        }
    }
}

