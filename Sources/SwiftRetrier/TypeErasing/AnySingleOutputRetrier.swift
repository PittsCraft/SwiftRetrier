import Foundation
import Combine

public class AnySingleOutputRetrier<Value: Sendable>: AnyRetrier<Value>, SingleOutputRetrier {

    private let outputBlock: @Sendable () async throws -> Output

    public init<R>(_ retrier: R) where R: SingleOutputRetrier, R.Output == Value {
        self.outputBlock = { try await retrier.value }
        super.init(retrier)
    }

    public var value: Output {
        get async throws {
            try await outputBlock()
        }
    }
}

extension SingleOutputRetrier {
    public func eraseToAnySingleOutputRetrier() -> AnySingleOutputRetrier<Output> {
        AnySingleOutputRetrier<Output>(self)
    }
}
