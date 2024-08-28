import Foundation
@preconcurrency import Combine

public struct JobRetrier<T: Sendable>: @unchecked Sendable {
    public typealias Failure = Never
    public typealias Output = RetrierEvent<T>

    let policy: RetryPolicy
    let conditionPublisher: AnyPublisher<Bool, Never>?
    var receiveEvent: @Sendable @MainActor (RetrierEvent<T>) -> Void = { _ in }
    let job: Job<T>
}

extension JobRetrier: Publisher {

    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, RetrierEvent<T> == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension JobRetrier {

    var value: T {
        get async throws {
            try await publisher
                .success()
                .cancellableFirst
        }
    }
}

private extension JobRetrier {

    @MainActor
    func nextDataOnFailure(_ failure: AttemptFailure, data: TrialData) -> TrialData? {
        switch data.retryPolicy.shouldRetry(on: failure) {
        case .giveUp:
            nil
        case .retry(let delay):
                .init(
                    start: data.start,
                    attemptIndex: data.attemptIndex + 1,
                    retryPolicy: data.retryPolicy.policyAfter(attemptFailure: failure, delay: delay),
                    delay: delay
                )
        }
    }

    var trialPublisher: AnyPublisher<RetrierEvent<T>, Never> {
        let subject = PassthroughSubject<(TrialData), Never>()
        let result = subject
            .asyncMapLatest { (data: TrialData) -> (Result<T, Error>, TrialData) in
                try await Task.sleep(nanoseconds: UInt64(data.delay * 1_000_000_000))
                do {
                    return try await (Result.success(job()), data)
                } catch {
                    return (Result.failure(error), data)
                }
            }
            .map { [subject] result, data in
                MainActor.assumeIsolated {
                    switch result {
                    case .failure(let error):
                        let failure = AttemptFailure(trialStart: data.start, index: data.attemptIndex, error: error)
                        let event = RetrierEvent<T>.attemptFailure(failure)
                        if let nextData = nextDataOnFailure(failure, data: data) {
                            subject.send(nextData)
                            return [event].publisher
                        }
                        subject.send(completion: .finished)
                        return [event, .completion(failure.error)].publisher
                    case .success(let output):
                        subject.send(completion: .finished)
                        return [.attemptSuccess(output), .completion(nil)].publisher
                    }
                }
            }
            .switchToLatest()
            .map { $0 as RetrierEvent<T>? }
            .replaceError(with: nil)
            .compactMap { $0 }
            .eraseToAnyPublisher()
        subject.send(.init(start: Date(), attemptIndex: 0, retryPolicy: policy, delay: 0))
        return result
    }

    func conditionalPublisher(
        conditionPublisher: AnyPublisher<Bool, Never>?,
        trialPublisher: AnyPublisher<RetrierEvent<T>, Never>
    ) -> AnyPublisher<RetrierEvent<T>, Never> {
        let conditionPublisher = conditionPublisher ?? Just(true).eraseToAnyPublisher()
        let conditionSubject = CurrentValueSubject<Bool, Never>(false)
        let subscription = conditionPublisher
            .sink {
                conditionSubject.value = $0
            }
        return conditionSubject
            .map { condition in
                if condition {
                    trialPublisher
                        .handleEvents(receiveCompletion: { _ in
                            subscription.cancel()
                            conditionSubject.send(completion: .finished)
                        }, receiveCancel: {
                            subscription.cancel()
                            conditionSubject.send(completion: .finished)
                        })
                        .eraseToAnyPublisher()
                } else {
                    Empty<RetrierEvent<T>, Never>().eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    var publisher: AnyPublisher<RetrierEvent<T>, Never> {
        conditionalPublisher(conditionPublisher: conditionPublisher, trialPublisher: trialPublisher)
            .handleEvents(receiveOutput: { output in
                MainActor.assumeIsolated {
                    receiveEvent(output)
                }
            })
            .eraseToAnyPublisher()
    }
}

private struct TrialData: Sendable {
    let start: Date
    let attemptIndex: UInt
    let retryPolicy: RetryPolicy
    let delay: TimeInterval
}
