import Foundation
import Combine

public class AnyRetrier<Output>: Retrier {

    public let publisherBlock: () -> AnyPublisher<RetrierEvent<Output>, Never>
    private let cancelBlock: () -> Void

    public init<R>(_ retrier: R) where R: Retrier, R.Output == Output {
        self.publisherBlock = retrier.publisher
        self.cancelBlock = retrier.cancel
    }

    public func publisher() -> AnyPublisher<RetrierEvent<Output>, Never> {
        publisherBlock()
    }

    public func cancel() {
        cancelBlock()
    }
}

extension Retrier {
    public func eraseToAnyRetrier() -> AnyRetrier<Output> {
        AnyRetrier<Output>(self)
    }
}
