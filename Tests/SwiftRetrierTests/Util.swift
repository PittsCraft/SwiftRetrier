import Foundation
import SwiftRetrier
import XCTest

let defaultTimeout: TimeInterval = 3

struct TestError: Error, Equatable {
    var message: String = ""
}

func sameEvents<T: Equatable>(_ event1: RetrierEvent<T>, _ event2: RetrierEvent<T>) -> Bool {
    switch (event1, event2) {
    case (.attemptSuccess(let value1), .attemptSuccess(let value2)):
        value1 == value2
    case (.attemptFailure(let failure1), .attemptFailure(let failure2)):
        failure1.index == failure2.index && (failure1.error as? TestError) == (failure2.error as? TestError)
    case (.completion(let error1), .completion(let error2)):
        (error1 == nil) && (error2 == nil) || (error1 as? TestError) == (error2 as? TestError)
    default:
        false
    }
}

func assertSameSequence<T: Equatable>(_ sequence1: [RetrierEvent<T>], _ sequence2: [RetrierEvent<T>]) {
    XCTAssertEqual(sequence1.count, sequence2.count, "Events count differs from expected one")
    XCTAssertTrue(zip(sequence1, sequence2).allSatisfy { sameEvents($0, $1) }, "Events should be the same")
}
