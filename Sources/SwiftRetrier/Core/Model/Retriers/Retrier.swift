import Foundation
import Combine

public protocol Retrier: Cancellable, AnyObject {
    associatedtype Output

    func publisher() -> AnyPublisher<RetrierEvent<Output>, Never>
}

public extension Retrier {

    func publisher(propagateCancellation: Bool) -> AnyPublisher<RetrierEvent<Output>, Never> {
        if propagateCancellation {
            return publisher()
                .handleEvents(receiveCancel: { [self] in cancel() })
                .eraseToAnyPublisher()
        } else {
            return publisher()
        }
    }

    func successPublisher(propagateCancellation: Bool = false) -> AnyPublisher<Output, Never> {
        publisher(propagateCancellation: propagateCancellation)
            .success()
    }

    func failurePublisher(propagateCancellation: Bool = false) -> AnyPublisher<AttemptFailure, Never> {
        publisher(propagateCancellation: propagateCancellation)
            .failure()
    }

    func completionPublisher(propagateCancellation: Bool = false) -> AnyPublisher<Error?, Never> {
        publisher(propagateCancellation: propagateCancellation)
            .completion()
    }
}
