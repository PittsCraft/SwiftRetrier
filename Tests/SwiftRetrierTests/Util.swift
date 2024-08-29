import Foundation

let defaultTimeout: TimeInterval = 3

struct TestError: Error, Equatable {
    var message: String = ""
}
