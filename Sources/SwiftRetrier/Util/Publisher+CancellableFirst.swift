import Foundation
@preconcurrency import Combine

// From https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77
enum AsyncError: Error {
    case finishedWithoutValue
}

extension Publisher where Self: Sendable {

    var cancellableFirst: Output {
        get async throws {
            let executor = await CancellableExecutor()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    Task { @MainActor [executor] in
                        executor.subscribeIfPossible {
                            first()
                                .sink { result in
                                    switch result {
                                    case .finished:
                                        continuation.resume(throwing: AsyncError.finishedWithoutValue)
                                    case let .failure(error):
                                        continuation.resume(throwing: error)
                                    }
                                    executor.cancel()
                                } receiveValue: { value in
                                    continuation.resume(with: .success(value))
                                    executor.cancel()
                                }
                        }
                    }

                }
            } onCancel: {
                Task { @MainActor in
                    executor.cancel()
                }
            }
        }
    }
}

@MainActor
private final class CancellableExecutor {

    private(set) var wasCancelled: Bool = false
    var subscription: AnyCancellable?

    func cancel() {
        subscription?.cancel()
        wasCancelled = true
    }

    func subscribeIfPossible(_ subscription: () -> AnyCancellable) {
        guard !wasCancelled else {
            return
        }
        self.subscription = subscription()
    }
}
