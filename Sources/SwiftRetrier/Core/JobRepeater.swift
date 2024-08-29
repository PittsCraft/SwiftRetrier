import Foundation
@preconcurrency import Combine

public struct JobRepeater<Value: Sendable>: Sendable {
    public typealias Failure = Never
    public typealias Output = RetrierEvent<Value>

    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
    var receiveEvent: @Sendable @MainActor (RetrierEvent<Value>) -> Void = { _ in }
    let job: Job<Value>
}

extension JobRepeater: Publisher {

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

private extension JobRepeater {

    var publisher: AnyPublisher<RetrierEvent<Value>, Never> {
        LazyPublisherBuilder {
            let singlePublisher = JobRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            let repeatSubject = CurrentValueSubject<TimeInterval, Never>(0)
            return repeatSubject
                .map {
                    Just(())
                        .delay(for: .seconds($0), scheduler: RunLoop.main)
                        .flatMap {
                            singlePublisher
                                .compactMap { event in
                                    guard case .completion(let error) = event else {
                                        return event
                                    }
                                    if error == nil {
                                        repeatSubject.send(repeatDelay)
                                        return nil
                                    } else {
                                        repeatSubject.send(completion: .finished)
                                        return event
                                    }
                                }
                        }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { output in
                    MainActor.assumeIsolated {
                        receiveEvent(output)
                    }
                })
        }
        .eraseToAnyPublisher()
    }
}


