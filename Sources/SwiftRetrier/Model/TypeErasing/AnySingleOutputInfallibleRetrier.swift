import Foundation
import Combine

public class AnySingleOutputInfallibleRetrier<Output>: AnyInfallibleRetrier<Output>, SingleOutputInfallibleRetrier {

    private let outputBlock: () async throws -> Output

    public init<R>(_ retrier: R) where R: SingleOutputInfallibleRetrier, R.Output == Output {
        self.outputBlock = { try await retrier.value }
        super.init(retrier)
    }

    public var value: Output {
        get async throws {
            try await outputBlock()
        }
    }
}

extension SingleOutputInfallibleRetrier {
    public func eraseToAnySingleOutputInfallibleRetrier() -> AnySingleOutputInfallibleRetrier<Output> {
        AnySingleOutputInfallibleRetrier<Output>(self)
    }
}
