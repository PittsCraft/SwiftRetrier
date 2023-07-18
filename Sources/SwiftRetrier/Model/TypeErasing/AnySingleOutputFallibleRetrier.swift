import Foundation
import Combine

public class AnySingleOutputFallibleRetrier<Value>: AnyFallibleRetrier<Value>, SingleOutputFallibleRetrier {

    private let outputBlock: () async throws -> Output

    public init<R>(_ retrier: R) where R: SingleOutputFallibleRetrier, R.Output == Value {
        self.outputBlock = { try await retrier.value }
        super.init(retrier)
    }

    public var value: Output {
        get async throws {
            try await outputBlock()
        }
    }
}

extension SingleOutputFallibleRetrier {
    public func eraseToAnySingleOutputFallibleRetrier() -> AnySingleOutputFallibleRetrier<Output> {
        AnySingleOutputFallibleRetrier<Output>(self)
    }
}
