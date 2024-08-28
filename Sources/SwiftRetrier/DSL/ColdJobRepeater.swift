import Foundation
@preconcurrency import Combine

public struct ColdJobRepeater<T: Sendable>: Sendable {
    public typealias Failure = Never
    public typealias Output = RetrierEvent<T>

    let policy: RetryPolicy
    let repeatDelay: TimeInterval
    let conditionPublisher: AnyPublisher<Bool, Never>?
    var receiveEvent: @Sendable @MainActor (RetrierEvent<T>) -> Void = { _ in }
    let job: Job<T>
}

extension ColdJobRepeater: Publisher {

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension ColdJobRepeater {

    func giveUp(on giveUpCriteria: @escaping GiveUpCriteria) -> ColdJobRepeater {
        let policy = policy.giveUp(on: giveUpCriteria)
        return ColdJobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpAfter(maxAttempts: UInt) -> ColdJobRepeater {
        let policy = policy.giveUpAfter(maxAttempts: maxAttempts)
        return ColdJobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpAfter(timeout: TimeInterval) -> ColdJobRepeater {
        let policy = policy.giveUpAfter(timeout: timeout)
        return ColdJobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func giveUpOnErrors(matching finalErrorCriteria: @escaping @Sendable @MainActor (Error) -> Bool) -> ColdJobRepeater {
        let policy = policy.giveUpOnErrors(matching: finalErrorCriteria)
        return ColdJobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher,
            receiveEvent: receiveEvent,
            job: job
        )
    }

    func onlyWhen<P>(
        _ conditionPublisher: P
    ) -> ColdJobRepeater where P: Publisher, P.Output == Bool, P.Failure == Never {
        ColdJobRepeater(
            policy: policy,
            repeatDelay: repeatDelay,
            conditionPublisher: conditionPublisher.combineWith(condition: self.conditionPublisher),
            receiveEvent: receiveEvent,
            job: job
        )
    }
}

private extension ColdJobRepeater {

    var publisher: AnyPublisher<RetrierEvent<T>, Never> {
        let singlePublisher = ColdJobRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
        let repeatSubject = PassthroughSubject<TimeInterval, Never>()
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
            .eraseToAnyPublisher()
    }
}


