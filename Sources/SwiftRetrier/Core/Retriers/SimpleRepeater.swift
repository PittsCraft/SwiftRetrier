import Foundation
import Combine

/// Repeats trials (retry sequences) separated by a fixed delay, using an underlying retrier.
///
/// All attempts of the underlying retrier are relayed.
///
/// Behavior:
/// ```swift
/// while(true) {
///   let retrier = createRetrier(policy, job)
///   do {
///     try await retrier.value
///     // On success, sleep before begining another trial
///     await sleep(repeatDelay)
///   } catch {
///     // On failure, complete with failure
///     finish(with: error)
///     break
///   }
/// }
/// ```
///
/// On cancellation, the publisher emits a completion embedding a `CancellationError`then finishes.
public class SimpleRepeater<Output>: Repeater, Retrier {

    private let retrierBuilder: () -> AnySingleOutputRetrier<Output>
    private var retrier: AnySingleOutputRetrier<Output>?
    private let eventSubject = PassthroughSubject<RetrierEvent<Output>, Never>()
    private let repeatDelay: TimeInterval
    private var retrierSubscription: AnyCancellable?
    private var cancelled = false

    public init<R>(repeatDelay: TimeInterval,
                   retrierBuilder: @escaping () -> R) where R: SingleOutputRetrier, R.Output == Output {
        self.repeatDelay = repeatDelay
        self.retrierBuilder = { retrierBuilder().eraseToAnySingleOutputRetrier() }
        onMain { [self] in
            startRetrier()
        }
    }

    public convenience init<P>(
        policy: RetryPolicy,
        conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
        repeatDelay: TimeInterval,
        job: @escaping Job<Output>
    ) where P: Publisher, P.Output == Bool, P.Failure == Never {
        if let conditionPublisher {
            self.init(repeatDelay: repeatDelay,
                      retrierBuilder: {
                ConditionalRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            })
        } else {
            self.init(repeatDelay: repeatDelay,
                      retrierBuilder: {
                SimpleRetrier(policy: policy, job: job)
            })
        }
    }

    private func startRetrier() {
        guard !cancelled else { return }
        let retrier = retrierBuilder()
        self.retrier = retrier
        bind(retrier: retrier)
    }

    private func bind(retrier: AnySingleOutputRetrier<Output>) {
        retrierSubscription = retrier.publisher()
        // We retain self here, so that this repeater keeps working even if it's not retained anywhere else
            .sink { [self] in
                if case .completion(let error) = $0 {
                    if error == nil {
                        // Retrier finished successfully. Don't send completion event
                        DispatchQueue.main.asyncAfter(deadline: .now() + .init(floatLiteral: repeatDelay)) { [self] in
                            startRetrier()
                        }
                    } else {
                        eventSubject.send($0)
                        eventSubject.send(completion: .finished)
                    }
                    retrierSubscription?.cancel()
                } else {
                    eventSubject.send($0)
                }
            }
    }

    public func publisher() -> AnyPublisher<RetrierEvent<Output>, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            cancelled = true
            retrierSubscription?.cancel()
            retrier?.cancel()
            eventSubject.send(.completion(CancellationError()))
            eventSubject.send(completion: .finished)
        }
    }
}
