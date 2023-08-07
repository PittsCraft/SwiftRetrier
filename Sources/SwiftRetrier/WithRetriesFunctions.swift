import Foundation
import Combine

private func subscribeAndAwait<R>(
    retrier: R,
    attemptFailureHandler: ((AttemptFailure) -> Void)?
) async throws -> R.Output where R: SingleOutputRetrier {
    var cancellables = Set<AnyCancellable>()
    if let attemptFailureHandler {
        retrier.failurePublisher()
            .sink(receiveCompletion: { _ in },
                  receiveValue: attemptFailureHandler)
            .store(in: &cancellables)
    }
    do {
        let result = try await retrier.cancellableValue
        cancellables.removeAll()
        return result
    } catch {
        cancellables.removeAll()
        throw error
    }
}

public func withRetries<Value, P: Publisher<Bool, Never>>(
    policy: RetryPolicy = Policy.exponentialBackoff(),
    onlyWhen conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    attemptFailureHandler: ((AttemptFailure) -> Void)? = nil,
    job: @escaping Job<Value>
) async throws -> Value {
    try await subscribeAndAwait(retrier: retrier(policy: policy,
                                                 conditionPublisher: conditionPublisher,
                                                 job: job),
                                attemptFailureHandler: attemptFailureHandler)
}

public func withRetries<Value, P: Publisher<Bool, Never>>(
    policy: RetryPolicy = Policy.exponentialBackoff(),
    repeatEvery repeatDelay: TimeInterval,
    propagateCancellation: Bool = false,
    onlyWhen conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
    job: @escaping Job<Value>
) -> AnyPublisher<RetrierEvent<Value>, Never> {
    retrier(policy: policy,
            conditionPublisher: conditionPublisher,
            repeatDelay: repeatDelay,
            job: job)
    .publisher(propagateCancellation: propagateCancellation)
}
