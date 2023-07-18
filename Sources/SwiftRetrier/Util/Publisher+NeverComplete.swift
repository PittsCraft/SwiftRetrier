import Foundation
import Combine

extension Publisher {
    func neverComplete<NewFailure>() -> AnyPublisher<Output, NewFailure> {
        self
            .catch { _ in Empty(completeImmediately: false) }
            .append(Empty(completeImmediately: false))
            .setFailureType(to: NewFailure.self)
            .eraseToAnyPublisher()
    }
}
