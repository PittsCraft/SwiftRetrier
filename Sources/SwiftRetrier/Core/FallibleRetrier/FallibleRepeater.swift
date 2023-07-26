import Foundation
import Combine

/// Repeats trials (retry sequences) separated by a fixed delay, using an underlying fallible retrier.
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
/// On cancellation, the publisher finishes without emitting anything else.
public class FallibleRepeater<Output>: Repeater, FallibleRetrier {

    private let retrierBuilder: () -> AnySingleOutputFallibleRetrier<Output>

    private let repeatDelay: TimeInterval
    private let retrierSubject = CurrentValueSubject<AnySingleOutputFallibleRetrier<Output>?, Never>(nil)
    private let completionSubject = CurrentValueSubject<Subscribers.Completion<Error>?, Never>(nil)
    private var retrierSubscriptions = Set<AnyCancellable>()
    private var cancelled = false

    public init<R>(repeatDelay: TimeInterval,
                   retrierBuilder: @escaping () -> R) where R: SingleOutputFallibleRetrier, R.Output == Output {
        self.repeatDelay = repeatDelay
        self.retrierBuilder = { retrierBuilder().eraseToAnySingleOutputFallibleRetrier() }
        onMain { [self] in
            startRetrier()
        }
    }

    public convenience init<P>(
        policy: FallibleRetryPolicy,
        conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
        repeatDelay: TimeInterval,
        job: @escaping Job<Output>
    ) where P: Publisher, P.Output == Bool, P.Failure == Never {
        if let conditionPublisher {
            self.init(repeatDelay: repeatDelay,
                      retrierBuilder: {
                ConditionalFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            })
        } else {
            self.init(repeatDelay: repeatDelay,
                      retrierBuilder: {
                SimpleFallibleRetrier(policy: policy, job: job)
            })
        }
    }

    private func startRetrier() {
        guard !cancelled else { return }
        let retrier = retrierBuilder()
        retrierSubject.send(retrier)
        bindFailure(retrier: retrier)
        bindSuccess(retrier: retrier)
    }

    private func bindFailure(retrier: AnySingleOutputFallibleRetrier<Output>) {
        retrier.resultPublisher
            .sink { [unowned self] in
                if case .failure(let error) = $0 {
                    send(completion: .failure(error))
                }
            }
            .store(in: &retrierSubscriptions)
    }

    private func bindSuccess(retrier: AnySingleOutputFallibleRetrier<Output>) {
        retrier.resultPublisher
            .compactMap {
                if case .success = $0 {
                    return ()
                }
                return nil
            }
            .delay(for: .init(floatLiteral: repeatDelay), scheduler: DispatchQueue.main)
        // We retain self here, so that this repeater keeps working even if it's not retained anywhere else
            .sink { [self] in
                retrierSubscriptions.removeAll()
                startRetrier()
            }
            .store(in: &retrierSubscriptions)
    }

    private func send(completion: Subscribers.Completion<Error>) {
        retrierSubscriptions.removeAll()
        completionSubject.send(completion)
        completionSubject.send(completion: .finished)
        retrierSubject.send(completion: .finished)
    }

    public func publisher() -> AnyPublisher<Result<Output, Error>, Error> {
        let result: AnyPublisher<Result<Output, Error>, Error> = retrierSubject
            .compactMap { $0 }
            .combineLatest(completionSubject)
            .map { retrier, completion in
                if let completion {
                    switch completion {
                    case .finished:
                        return Empty<Result<Output, Error>, Error>()
                            .eraseToAnyPublisher()
                    case .failure(let failure):
                        return Fail(error: failure).eraseToAnyPublisher()
                    }
                } else {
                    return retrier
                        .publisher()
                        .neverComplete()
                        .eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        return result
    }

    public func cancel() {
        onMain { [self] in
            cancelled = true
            send(completion: .finished)
            retrierSubject.value?.cancel()
        }
    }
}
