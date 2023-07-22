import Foundation
import Combine

public class ConditionalFallibleRetrier<Output>: SingleOutputFallibleRetrier, SingleOutputConditionalRetrier {

    private let policy: FallibleRetryPolicyInstance
    private let job: Job<Output>

    private var retrier: SimpleRetrier<Output>?
    private var successValue: Output?
    private var conditionSubscription: AnyCancellable?
    private var retrierSubscription: AnyCancellable?
    private let conditionPublisher: AnyPublisher<Bool, Never>

    private let subject = PassthroughSubject<Result<Output, Error>, Error>()

    public init<P: Publisher<Bool, Never>>(policy: FallibleRetryPolicyInstance,
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
                receiveCompletion: { [self] completion in
                    if lastCondition != true {
                        // The task will never be executed anymore and continuation will never be called with a relevant
                        // output.
                        subject.send(completion: .failure(RetryError.conditionPublisherCompleted))
                    }
                },
                receiveValue:{ [unowned self] condition in
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
        self.retrier = nil
        subject.send(.failure(CancellationError()))
    }

    private func bind(retrier: SimpleRetrier<Output>) {
        retrierSubscription = retrier.attemptPublisher
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

    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Error> {
        subject.eraseToAnyPublisher()
    }

    public func cancel() {
        retrierSubscription?.cancel()
        conditionSubscription?.cancel()
        retrier?.cancel()
        subject.send(completion: .finished)
    }
}
