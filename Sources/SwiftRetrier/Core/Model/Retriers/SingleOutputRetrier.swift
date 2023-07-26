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

extension SingleOutputRetrier {

    var resultPublisher: AnyPublisher<Result<Output, Failure>, Never> {
        publisher()
            .compactMap {
                switch $0 {
                case .failure:
                    return nil
                case .success(let value):
                    return .success(value)
                }
            }
            .catch {
                Just(.failure($0))
            }
            .eraseToAnyPublisher()
    }
}
