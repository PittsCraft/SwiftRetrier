import Foundation
import Combine

/// Single output fallible retrier
///
/// Retries with delay according to its policy, until:
/// - **an attempt succeeds:** any awaiting on the `value` property will be returned
///  the success value, the publisher emits an attempt success embedding this value then finishes.
/// - **the policy gives up:** any awaiting on the `value` property will throw with
/// the last attempt error, the publisher emits the attempt failure before completing with a
/// failure embedding the attempt error.
/// - **the retrier is canceled:** any awaiting on the `value` property will throw a `CancellationError`, the publisher
/// finishes without emitting anything else.
public class SimpleFallibleRetrier<Output>: SingleOutputFallibleRetrier {

    private let subject = PassthroughSubject<Result<Output, Error>, Error>()
    private var task: Task<Output, Error>!

    public init(policy: FallibleRetryPolicy, job: @escaping Job<Output>) {
        self.task = createTask(policy: policy.freshFallibleCopy(), job: job)
    }

    @MainActor
    private func sendAttemptFailure(_ error: Error) {
        subject.send(.failure(error))
    }

    @MainActor
    private func finish(with result: Output) {
        guard !Task.isCancelled else {
            subject.send(completion: .finished)
            return
        }
        subject.send(.success(result))
        subject.send(completion: .finished)
    }

    @MainActor
    private func finish(throwing error: Error) {
        guard !Task.isCancelled else {
            subject.send(completion: .finished)
            return
        }
        subject.send(completion: .failure(error))
    }

    private func createTask(policy: FallibleRetryPolicy, job: @escaping Job<Output>) -> Task<Output, Error> {
        Task {
            // Ensure we don't start before any ongoing business on main actor is finished
            await MainActor.run {}
            do {
                var attemptIndex: UInt = 0
                while true {
                    try Task.checkCancellation()
                    do {
                        let result = try await job()
                        await finish(with: result)
                        return result
                    } catch {
                        await sendAttemptFailure(error)
                        try Task.checkCancellation()
                        let retryDecision = await MainActor.run { [attemptIndex] in
                            policy.shouldRetry(on: AttemptFailure(index: attemptIndex, error: error))
                        }
                        switch retryDecision {
                        case .giveUp:
                            throw error
                        case .retry(delay: let delay):
                            try await Task.sleep(nanoseconds: nanoseconds(delay))
                            attemptIndex += 1
                        }
                    }
                }
            } catch {
                await finish(throwing: error)
                throw error
            }
        }
    }

    public var value: Output {
        get async throws {
            try await task.value
        }
    }

    public func publisher() -> AnyPublisher<Result<Output, Error>, Error> {
        subject
            .eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            task.cancel()
            subject.send(completion: .finished)
        }
    }
}
