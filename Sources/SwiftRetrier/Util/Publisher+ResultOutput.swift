import Foundation
import Combine

protocol ResultProtocol {
    associatedtype Success
    associatedtype Failure: Error

    var asResult: Result<Success, Failure> { get }
}

extension Result: ResultProtocol {

    var asResult: Self {
        self
    }
}

extension Publisher where Output: ResultProtocol {

    func success() -> AnyPublisher<Output.Success, Failure> {
        self
            .flatMap {
                switch $0.asResult {
                case .success(let output):
                    return Just(output)
                        .eraseToAnyPublisher()
                case .failure:
                    return Empty().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    func failure() -> AnyPublisher<Output.Failure, Failure> {
        self
            .flatMap {
                switch $0.asResult {
                case .success:
                    return Empty<Output.Failure, Failure>()
                        .eraseToAnyPublisher()
                case .failure(let error):
                    return Just(error)
                        .setFailureType(to: Failure.self)
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}
