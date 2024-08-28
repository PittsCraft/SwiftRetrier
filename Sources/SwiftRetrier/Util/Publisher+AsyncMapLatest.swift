import Foundation
@preconcurrency import Combine

/// Adapted from : https://www.swiftbysundell.com/articles/calling-async-functions-within-a-combine-pipeline/
/// to handle cancellation properly and be compatible with Swift 6 mode
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
                let subject = PassthroughSubject<T, Error>()
                let task = Task { @MainActor [subject] in
                    do {
                        let output = try await transform(value)
                        subject.send(output)
                        subject.send(completion: .finished)
                    } catch {
                        subject.send(completion: .failure(error))
                    }
                }
                return subject.handleEvents(receiveCancel: { task.cancel() })
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}
