import Foundation
import Combine

/// Single output conditional infallible retrier.
///
/// When the condition is `true`, retries according to the policy until:
/// - **the condition becomes `false`:** an attempt failure with `CancellationError` is emited by the publisher if a job
/// was indeed interrupted, then the retrier waits for the condition to become `true` again
/// - **an attempt succeeds:** any awaiting on the `value` property will be returned
/// the success value, the publisher emits an attempt success embedding this value then finishes.
/// - **the retrier is canceled:** any awaiting on the `value` property will throw a `CancellationError`, the publisher
/// finishes without emitting anything else.
///
/// If the condition becomes false then true, the retry policy is restarted from its initial state (if any).
///
/// If the condition publisher completes and it had not emitted any value or the last value it emitted was `false`
/// then any awaiting on the `value` property `RetryError.conditionPublisherCompleted` and the publisher finishes.
public class ConditionalInfallibleRetrier<T>: SingleOutputInfallibleRetrier, SingleOutputConditionalRetrier {

    private let innerRetrier: ConditionalFallibleRetrier<T>

    public init<P: Publisher<Bool, Never>>(policy: InfallibleRetryPolicyInstance,
                                           conditionPublisher: P,
                                           job: @escaping Job<T>) {
        self.innerRetrier = ConditionalFallibleRetrier(policy: policy.toFallibleRetryPolicy().instance(),
                                                       conditionPublisher: conditionPublisher,
                                                       job: job)
    }

    public var attemptPublisher: AnyPublisher<Result<T, Error>, Never> {
        innerRetrier.attemptPublisher
            .catch { _ in Empty() }
            .eraseToAnyPublisher()
    }

    public var value: T {
        get async throws {
            try await innerRetrier.value
        }
    }

    public func cancel() {
        innerRetrier.cancel()
    }
}
