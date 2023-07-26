import Foundation
import Combine

public protocol BaseRetrier: Cancellable, AnyObject {
    associatedtype Output
    associatedtype Failure: Error

    func publisher() -> AnyPublisher<Result<Output, Error>, Failure>
}

public extension BaseRetrier {

    func publisher(propagateCancellation: Bool) -> AnyPublisher<Result<Output, Error>, Failure> {
        if propagateCancellation {
            return publisher()
                .handleEvents(receiveCancel: { [self] in cancel() })
                .eraseToAnyPublisher()
        } else {
            return publisher()
        }
    }

    func successPublisher(propagateCancellation: Bool = false) -> AnyPublisher<Output, Failure> {
        publisher(propagateCancellation: propagateCancellation)
            .success()
    }

    func failurePublisher(propagateCancellation: Bool = false) -> AnyPublisher<Error, Failure> {
        publisher(propagateCancellation: propagateCancellation)
            .failure()
    }
}
