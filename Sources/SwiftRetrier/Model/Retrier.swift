import Foundation
import Combine

public protocol Retrier: Cancellable {
    associatedtype Output
    associatedtype Failure: Error

    var attemptPublisher: AnyPublisher<Result<Output, Error>, Failure> { get }
}

public extension Retrier {
    
    var attemptSuccessPublisher: AnyPublisher<Output, Failure> {
        attemptPublisher.success()
    }

    var attemptFailurePublisher: AnyPublisher<Error, Failure> {
        attemptPublisher.failure()
    }
}
