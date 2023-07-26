import Foundation
import Combine

public class AnyRetrier<Output, Failure: Error>: BaseRetrier {

    public let publisherBlock: () -> AnyPublisher<Result<Output, Error>, Failure>
    private let cancelBlock: () -> Void

    public init<R>(_ retrier: R) where R: BaseRetrier, R.Output == Output, R.Failure == Failure {
        self.publisherBlock = retrier.publisher
        self.cancelBlock = retrier.cancel
    }

    public init<R>(_ retrier: R) where R: BaseRetrier, R.Output == Output, R.Failure == Never {
        self.publisherBlock = {
            retrier.publisher()
                .setFailureType(to: Failure.self)
                .eraseToAnyPublisher()
        }
        self.cancelBlock = retrier.cancel
    }

    public func publisher() -> AnyPublisher<Result<Output, Error>, Failure> {
        publisherBlock()
    }

    public func cancel() {
        cancelBlock()
    }
}

extension BaseRetrier {
    public func eraseToAnyRetrier() -> AnyRetrier<Output, Failure> {
        AnyRetrier<Output, Failure>(self)
    }
}
