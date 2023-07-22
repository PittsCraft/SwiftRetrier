import Foundation
import Combine

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
    
    public convenience init(repeatDelay: TimeInterval,
                            policy: FallibleRetryPolicyInstance,
                            job: @escaping Job<Output>) {
        self.init(repeatDelay: repeatDelay,
                  retrierBuilder: {
            SimpleRetrier(policy: policy, job: job)
        })
    }
    
    public convenience init<P>(
        repeatDelay: TimeInterval,
        policy: FallibleRetryPolicyInstance,
        conditionPublisher: P,
        job: @escaping Job<Output>
    ) where P: Publisher, P.Output == Bool, P.Failure == Never {
        self.init(repeatDelay: repeatDelay,
                  retrierBuilder: {
            ConditionalFallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
        })
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
        // We retain self here, so that this retrier keeps working even if it's not retained anywhere else
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
    
    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Error> {
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
                        .attemptPublisher
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
