import Foundation
@preconcurrency import Combine

// Adapted from https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77
public enum AsyncError: Error {
    case finishedWithoutValue
}

public extension Publisher where Self: Sendable, Output: Sendable {

    var cancellableFirst: Output {
        get async throws {
            let executor = await CancellableExecutor<Output>()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    Task { @MainActor in
                        executor.subscribeIfPossible(continuation) {
                            first()
                                .sink { completion in
                                    switch completion {
                                    case .finished:
                                        Task { @MainActor in
                                            executor.resume(with: .failure(AsyncError.finishedWithoutValue))
                                        }
                                    case let .failure(error):
                                        Task { @MainActor in
                                            executor.resume(with: .failure(error))
                                        }
                                    }
                                } receiveValue: { value in
                                    Task { @MainActor in
                                        executor.resume(with: .success(value))
                                    }
                                }
                        }
                    }

                }
            } onCancel: {
                Task { @MainActor in
                    executor.onCancel()
                }
            }
        }
    }
}

@MainActor
private final class CancellableExecutor<Output>: Sendable {

    private var finished: Bool = false
    private var subscription: AnyCancellable?
    private var continuation: CheckedContinuation<Output, any Error>?

    func resume(with result: sending Result<Output, any Error>) {
        guard !finished else { return }
        continuation?.resume(with: result)
        subscription?.cancel()
        finished = true
    }

    func subscribeIfPossible(
        _ continuation: CheckedContinuation<Output, any Error>,
        _ subscription: @Sendable @escaping () -> AnyCancellable
    ) {
        guard !finished else {
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        self.subscription = subscription()
    }

    func onCancel() {
        resume(with: .failure(CancellationError()))
    }
}
