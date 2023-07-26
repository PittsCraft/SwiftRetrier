import Foundation
import Combine

/// Single output conditional fallible retrier.
///
/// When the condition is `true`, retries according to the policy until:
/// - **the condition becomes `false`:** an attempt failure with `CancellationError` is emited by the publisher if a job
/// was indeed interrupted, then the retrier waits for the condition to become `true` again
/// - **an attempt succeeds:** any awaiting on the `value` property will be returned
///  the success value, the publisher emits an attempt success embedding this value then finishes.
/// - **the policy gives up:** any awaiting on the `value` property will throw with
/// the last attempt error, the publisher emits the attempt failure before completing with a
/// failure embedding the attempt error.
/// - **the retrier is canceled:** any awaiting on the `value` property will throw a `CancellationError`, the publisher
/// finishes without emitting anything else.
///
/// If the condition becomes false then true, the retry policy is restarted from its initial state (if any).
///
/// If the condition publisher completes and it had not emitted any value or the last value it emitted was `false`
/// then the retrier fails with `RetryError.conditionPublisherCompleted`.
public class ConditionalFallibleRetrier<Output>: SingleOutputFallibleRetrier, SingleOutputConditionalRetrier {

    private let policy: FallibleRetryPolicy
    private let job: Job<Output>

    private var retrier: SimpleFallibleRetrier<Output>?
    private var successValue: Output?
    private var conditionSubscription: AnyCancellable?
    private var retrierSubscription: AnyCancellable?
    private let conditionPublisher: AnyPublisher<Bool, Never>

    private let subject = PassthroughSubject<Result<Output, Error>, Error>()

    public init<P: Publisher<Bool, Never>>(policy: FallibleRetryPolicy,
                                           conditionPublisher: P,
                                           job: @escaping Job<Output>) {
        self.policy = policy
        self.job = job
        self.conditionPublisher = conditionPublisher.onMain()
        bindCondition()
    }

    private func bindCondition() {
        var lastCondition: Bool?
        conditionSubscription = conditionPublisher
            .removeDuplicates()
            .sink(
                // We retain self here, so that this retrier keeps working even if it's not retained anywhere else
                receiveCompletion: { [self] _ in
                    if lastCondition != true {
                        // The task will never be executed anymore and continuation will never be called with a relevant
                        // output.
                        subject.send(completion: .failure(RetryError.conditionPublisherCompleted))
                    }
                },
                receiveValue: { [unowned self] condition in
                    lastCondition = condition
                    if condition {
                        startRetrier()
                    } else {
                        stopRetrier()
                    }
                }
            )
    }

    private func startRetrier() {
        let retrier = SimpleFallibleRetrier(policy: policy, job: job)
        self.retrier = retrier
        bind(retrier: retrier)
    }

    private func stopRetrier() {
        guard let retrier else { return }
        retrierSubscription?.cancel()
        retrier.cancel()
        self.retrier = nil
        subject.send(.failure(CancellationError()))
    }

    private func bind(retrier: SimpleFallibleRetrier<Output>) {
        retrierSubscription = retrier.publisher()
            .sink(receiveCompletion: { [unowned self] in
                subject.send(completion: $0)
                conditionSubscription?.cancel()
            }, receiveValue: { [unowned self] in
                subject.send($0)
                if case .success(let value) = $0 {
                    successValue = value
                }
            })
    }

    public var value: Output {
        get async throws {
            try await withUnsafeThrowingContinuation { continuation in
                onMain { [self] in
                    if case .some(let value) = successValue {
                        continuation.resume(returning: value)
                        return
                    }
                    var subscription: AnyCancellable?
                    subscription = subject
                        .sink(receiveCompletion: {
                            switch $0 {
                            case .failure(let error):
                                continuation.resume(throwing: error)
                                subscription?.cancel()
                            case .finished:
                                continuation.resume(throwing: CancellationError())
                                subscription?.cancel()
                            }
                        }, receiveValue: {
                            if case .success(let value) = $0 {
                                continuation.resume(returning: value)
                                subscription?.cancel()
                            }
                        })
                }
            }
        }
    }

    public func publisher() -> AnyPublisher<Result<Output, Error>, Error> {
        subject.eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            retrierSubscription?.cancel()
            conditionSubscription?.cancel()
            retrier?.cancel()
            subject.send(completion: .finished)
        }
    }
}
