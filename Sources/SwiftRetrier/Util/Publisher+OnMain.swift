import Foundation
import Combine

extension Publisher {
    func onMain() -> AnyPublisher<Output, Failure> {
        flatMap {
            if Thread.isMainThread {
                return Just($0)
                    .setFailureType(to: Failure.self)
                    .eraseToAnyPublisher()
            } else {
                return Just($0)
                    .setFailureType(to: Failure.self)
                    .receive(on: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
        }
        .catch {
            if Thread.isMainThread {
                return Fail<Output, Failure>(error: $0)
                    .eraseToAnyPublisher()
            } else {
                return Fail(error: $0)
                    .receive(on: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
        }
        .append(
            Deferred {
                if Thread.isMainThread {
                    return Empty<Output, Failure>()
                        .eraseToAnyPublisher()
                } else {
                    return Empty<Output, Failure>()
                        .receive(on: DispatchQueue.main)
                        .eraseToAnyPublisher()
                }
            }
        )
        .eraseToAnyPublisher()
    }
}
