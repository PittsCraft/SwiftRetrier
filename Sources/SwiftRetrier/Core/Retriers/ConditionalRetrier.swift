import Foundation
import Combine

/// Single output conditional retrier.
///
/// When the condition is `true`, retries according to the policy until:
/// - **the condition becomes `false`:** an attempt failure with `CancellationError` is emited by the publisher if a job
/// was indeed interrupted, then the retrier waits for the condition to become `true` again
/// - **an attempt succeeds:** any awaiting on the `value` property will be returned
///  the success value, the publisher emits an attempt success embedding this value then
///  a completion with no error and finishes.
/// - **the policy gives up:** any awaiting on the `value` property will throw with
/// the last attempt error, the publisher emits the attempt failures, a completion embedding
/// the same error then finishes.
/// - **the retrier is canceled:** any awaiting on the `value` property will throw a `CancellationError`, the publisher
/// emits a completion embedding the same error then finishes.
///
/// If the condition becomes false then true, the retry policy is restarted from its initial state (if any),
/// but the further emitted attempt failures index won't be reset.
///
/// If the condition publisher completes and it had not emitted any value or the last value it emitted was `false`
/// then the retrier emits a completion embedding `RetryError.conditionPublisherCompleted` and finishes.
public class ConditionalRetrier<Output: Sendable>: SingleOutputRetrier, @unchecked Sendable {

    private let policy: RetryPolicy
    private let job: Job<Output>

    private var retrier: SimpleRetrier<Output>?
    private var finalEvent: RetrierEvent<Output>?
    private var conditionSubscription: AnyCancellable?
    private var retrierSubscription: AnyCancellable?
    private let conditionPublisher: AnyPublisher<Bool, Never>
    private var attemptIndex: UInt = 0

    private let subject = PassthroughSubject<RetrierEvent<Output>, Never>()

    public init<P: Publisher<Bool, Never>>(policy: RetryPolicy,
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
                        subject.send(.completion(RetryError.conditionPublisherCompleted))
                        subject.send(completion: .finished)
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
        let retrier = SimpleRetrier(policy: policy, job: job)
        self.retrier = retrier
        bind(retrier: retrier)
    }

    private func stopRetrier() {
        guard let retrier else { return }
        retrierSubscription?.cancel()
        retrier.cancel()
        subject.send(.attemptFailure(AttemptFailure(trialStart: retrier.trialStart,
                                                    index: attemptIndex,
                                                    error: CancellationError())))
        self.retrier = nil
        attemptIndex += 1
    }

    private func finish() {
        retrierSubscription?.cancel()
        conditionSubscription?.cancel()
        retrier?.cancel()
        subject.send(completion: .finished)
    }

    private func bind(retrier: SimpleRetrier<Output>) {
        retrierSubscription = retrier.publisher()
            .sink { [unowned self] in
                var event = $0
                switch $0 {
                    // Catch attempt failure to adjust attempt index
                case .attemptFailure(let attemptFailure):
                    event = .attemptFailure(AttemptFailure(trialStart: attemptFailure.trialStart,
                                                           index: attemptIndex,
                                                           error: attemptFailure.error))
                    attemptIndex += 1
                    // Remember final event for future await on value
                case .attemptSuccess:
                    finalEvent = $0
                case .completion(let error) where error != nil:
                    finalEvent = $0
                default:
                    break
                }
                subject.send(event)
                // If underlying retrier finished then we're done
                if case .completion = $0 {
                    finish()
                }
            }
    }

    public var value: Output {
        get async throws {
            try await withUnsafeThrowingContinuation { continuation in
                onMain { [self] in
                    // Already successfully finished?
                    if case .attemptSuccess(let value) = finalEvent {
                        continuation.resume(returning: value)
                        return
                    }
                    // Already unsuccessfully finished?
                    if case .completion(let error) = finalEvent, let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    // Else subscribe
                    var subscription: AnyCancellable?
                    subscription = subject
                        .sink {
                            switch $0 {
                            case .attemptSuccess(let value):
                                continuation.resume(returning: value)
                                subscription?.cancel()
                            case .attemptFailure:
                                break
                            case .completion(let error):
                                if let error {
                                    continuation.resume(throwing: error)
                                    subscription?.cancel()
                                }
                            }
                        }
                }
            }
        }
    }

    public func publisher() -> AnyPublisher<RetrierEvent<Output>, Never> {
        subject.eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            if finalEvent == nil {
                let event = RetrierEvent<Output>.completion(CancellationError())
                finalEvent = event
                subject.send(event)
            }
            finish()
        }
    }
}
