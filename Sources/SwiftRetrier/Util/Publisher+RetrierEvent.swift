import Foundation
import Combine

public protocol RetrierEventProtocol {
    associatedtype Output: Sendable

    var asRetrierEvent: RetrierEvent<Output> { get }
}

extension RetrierEvent: RetrierEventProtocol {

    public var asRetrierEvent: Self {
        self
    }
}

public extension Publisher where Output: RetrierEventProtocol, Failure == Never {

    func success() -> AnyPublisher<Output.Output, Never> {
        self
            .flatMap {
                switch $0.asRetrierEvent {
                case .attemptSuccess(let output):
                    return Just(output)
                        .eraseToAnyPublisher()
                default:
                    return Empty().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    func failure() -> AnyPublisher<AttemptFailure, Never> {
        self
            .flatMap {
                switch $0.asRetrierEvent {
                case .attemptFailure(let attemptFailure):
                    return Just(attemptFailure)
                        .eraseToAnyPublisher()
                default:
                    return Empty().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    func completion() -> AnyPublisher<Error?, Never> {
        self
            .flatMap {
                switch $0.asRetrierEvent {
                case .completion(let error):
                    return Just(error)
                        .setFailureType(to: Failure.self)
                        .eraseToAnyPublisher()
                default:
                    return Empty().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    func handleRetrierEvents(receiveEvent: @escaping @Sendable (Output) -> Void) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveOutput: receiveEvent)
    }
}
