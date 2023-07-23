import Foundation
import Combine

/// Single output infallible retrier
///
/// Retries with delay according to its policy, until:
/// - **an attempt succeeds:** any awaiting on the `value` property will be returned the success value,
/// the publisher emits an attempt success embedding this value then finishes.
/// - **the retrier is canceled:** any awaiting on the `value` property will throw a `CancellationError`, the publisher
/// finishes without emitting anything else.
public class SimpleInfallibleRetrier<Output>: SingleOutputInfallibleRetrier {

    private let policy: InfallibleRetryPolicy
    private let subject = PassthroughSubject<Result<Output, Error>, Never>()
    private var task: Task<Output, Error>!

    public init(policy: InfallibleRetryPolicyInstance, job: @escaping Job<Output>) {
        self.policy = policy.freshInfallibleCopy()
        self.task = createTask(job: job)
    }

    @MainActor
    private func finish(with result: Output) {
        subject.send(.success(result))
        subject.send(completion: .finished)
    }

    @MainActor
    private func finishOnCancel() {
        subject.send(completion: .finished)
    }

    @MainActor
    private func delay(attemptIndex: UInt, lastError: Error) -> TimeInterval {
        policy.retryDelay(attemptIndex: attemptIndex, lastError: lastError)
    }

    @MainActor
    private func sendAttemptFailure(_ error: Error) {
        subject.send(.failure(error))
    }

    private func createTask(job: @escaping Job<Output>) -> Task<Output, Error> {
        Task {
            var attemptIndex: UInt = 0
            await MainActor.run {}
            while true {
                do {
                    try Task.checkCancellation()
                    let result = try await job()
                    try Task.checkCancellation()
                    await finish(with: result)
                    return result
                } catch {
                    if Task.isCancelled {
                        await finishOnCancel()
                        throw CancellationError()
                    }
                    await sendAttemptFailure(error)
                    let delay = await delay(attemptIndex: attemptIndex, lastError: error)
                    do {
                        try await Task.sleep(nanoseconds: nanoseconds(delay))
                    } catch {}
                    attemptIndex += 1
                }
            }
        }
    }

    public var value: Output {
        get async throws {
            try await task.value
        }
    }

    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Never> {
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
