import Foundation
import Combine

public protocol SingleOutputRetrier: Retrier {

    var value: Output { get async throws }
}


public extension SingleOutputRetrier {

    var cancellableValue: Output {
        get async throws {
            try await withTaskCancellationHandler(operation: { try await value },
                                                  onCancel: { cancel() })
        }
    }
}
