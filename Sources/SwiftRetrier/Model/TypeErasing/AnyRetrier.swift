import Foundation
import Combine

public class AnyRetrier<Output, Failure: Error>: Retrier {

    public let attemptPublisher: AnyPublisher<Result<Output, Error>, Failure>
    private let cancelBlock: () -> Void

    public init<R>(_ retrier: R) where R: Retrier, R.Output == Output, R.Failure == Failure {
        self.attemptPublisher = retrier.attemptPublisher
        self.cancelBlock = retrier.cancel
    }

    public init<R>(_ retrier: R) where R: Retrier, R.Output == Output, R.Failure == Never {
        self.attemptPublisher = retrier.attemptPublisher
            .setFailureType(to: Failure.self).eraseToAnyPublisher()
        self.cancelBlock = retrier.cancel
    }

    public func cancel() {
        cancelBlock()
    }
}

extension Retrier {
    public func eraseToAnyRetrier() -> AnyRetrier<Output, Failure> {
        AnyRetrier<Output, Failure>(self)
    }
}
