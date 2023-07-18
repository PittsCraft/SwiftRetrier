import Foundation
import Combine

public class SimpleRetrier<Value>: SingleOutputFallibleRetrier {
    
    private let subject = PassthroughSubject<Result<Value, Error>, Error>()
    private var task: Task<Value, Error>!
    
    public init(policy: FallibleRetryPolicyInstance, job: @escaping Job<Value>) {
        self.task = createTask(policy: policy.freshFallibleCopy(), job: job)
    }
    
    @MainActor
    private func sendAttemptFailure(_ error: Error) {
        subject.send(.failure(error))
    }
    
    @MainActor
    private func finish(with result: Value) {
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
    
    private func createTask(policy: FallibleRetryPolicy, job: @escaping Job<Value>) -> Task<Value, Error> {
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
                            policy.shouldRetry(attemptIndex: attemptIndex, lastError: error)
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
    
    public var value: Value {
        get async throws {
            try await task.value
        }
    }
    
    public var attemptPublisher: AnyPublisher<Result<Value, Error>, Error> {
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
