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

    var resultPublisher: AnyPublisher<Result<Output, Error>, Never> {
        publisher()
            .compactMap {
                switch $0 {
                case .completion(let error):
                    if let error {
                        return .failure(error)
                    }
                    return nil
                case .attemptSuccess(let value):
                    return .success(value)
                case .attemptFailure:
                    return nil
                }
            }
            .eraseToAnyPublisher()
    }
}
