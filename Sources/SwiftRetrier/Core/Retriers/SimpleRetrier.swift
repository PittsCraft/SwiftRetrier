import Foundation
import Combine

/// Single output fallible retrier
///
/// Retries with delay according to its policy, until:
/// - **an attempt succeeds:** any awaiting on the `value` property will be returned
///  the success value, the publisher emits an attempt success embedding this value then finishes.
/// - **the policy gives up:** any awaiting on the `value` property will throw with
/// the last attempt error, the publisher emits the attempt failure then a completion embedding  the attempt error.
/// - **the retrier is canceled:** any awaiting on the `value` property will throw a `CancellationError`, the publisher
/// emits a completion embedding the same error then finishes.
public class SimpleRetrier<Output>: SingleOutputRetrier {

    private let subject = PassthroughSubject<RetrierEvent<Output>, Never>()
    private var task: Task<Output, Error>!

    public init(policy: RetryPolicy, job: @escaping Job<Output>) {
        self.task = createTask(policy: policy.freshCopy(), job: job)
    }

    @MainActor
    private func sendAttemptFailure(_ attemptFailure: AttemptFailure) {
        subject.send(.attemptFailure(attemptFailure))
    }

    @MainActor
    private func finish(with result: Output) {
        guard !Task.isCancelled else {
            return
        }
        subject.send(.attemptSuccess(result))
        subject.send(.completion(nil))
        subject.send(completion: .finished)
    }

    @MainActor
    private func finish(throwing error: Error) {
        guard !Task.isCancelled else {
            return
        }
        subject.send(.completion(error))
        subject.send(completion: .finished)
    }

    private func createTask(policy: RetryPolicy, job: @escaping Job<Output>) -> Task<Output, Error> {
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
                        let attemptFailure = AttemptFailure(index: attemptIndex, error: error)
                        await sendAttemptFailure(attemptFailure)
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

    public func publisher() -> AnyPublisher<RetrierEvent<Output>, Never> {
        subject
            .eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            subject.send(.completion(CancellationError()))
            subject.send(completion: .finished)
            task.cancel()
        }
    }
}
