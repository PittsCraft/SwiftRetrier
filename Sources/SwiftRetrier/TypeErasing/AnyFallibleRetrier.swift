import Foundation
import Combine

public class AnyFallibleRetrier<Output>: AnyRetrier<Output, Error>, FallibleRetrier {

    public init<R>(_ retrier: R) where R: FallibleRetrier, R.Output == Output {
        super.init(retrier)
    }
}

extension FallibleRetrier {
    public func eraseToAnyFallibleRetrier() -> AnyFallibleRetrier<Output> {
        AnyFallibleRetrier<Output>(self)
    }
}
