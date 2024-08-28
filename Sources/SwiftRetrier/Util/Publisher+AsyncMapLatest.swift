import Foundation
import Combine

/// Adapted from : https://www.swiftbysundell.com/articles/calling-async-functions-within-a-combine-pipeline/
/// to handle cancellation properly
public extension Publisher where Output: Sendable {

    /// Map output using an async closure.
    ///
    /// Each task running the async closure is cancelled as soon as another output is published or a subscription is cancelled.
    ///
    /// - Parameters:
    ///  - transform: transform closure
    /// - Returns: a publisher with closure's return value as output
    func asyncMapLatest<T: Sendable>(
        _ transform: @escaping @Sendable (Output) async throws -> T
    ) -> AnyPublisher<T, Error> {
        mapError { $0 as Error }
            .map { value in
                var task: Task<Void, Never>?
                return Future<T, Error> { (promise: @escaping (Result<T, Error>) -> Void) in
                    nonisolated(unsafe) let promise = promise
                    task = Task { @MainActor [promise] in
                        do {
                            let output = try await transform(value)
                            promise(.success(output))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }.handleEvents(receiveCancel: { task?.cancel() })
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}

private struct FakeSendableError<T: Error>: @unchecked Sendable, Error {
    let value: T
}
