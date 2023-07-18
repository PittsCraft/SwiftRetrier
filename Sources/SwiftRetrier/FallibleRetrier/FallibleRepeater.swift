import Foundation
import Combine

public class FallibleRepeater<Output>: Repeater, FallibleRetrier {

    private let retrierBuilder: () -> AnySingleOutputFallibleRetrier<Output>

    private let retrierSubject = PassthroughSubject<AnySingleOutputFallibleRetrier<Output>, Never>()
    private let completionSubject = CurrentValueSubject<Subscribers.Completion<Error>?, Never>(nil)
    private var task: Task<Void, Error>!

    public init<R>(repeatDelay: TimeInterval,
                   retrierBuilder: @escaping () -> R) where R: SingleOutputFallibleRetrier, R.Output == Output {
        self.retrierBuilder = { retrierBuilder().eraseToAnySingleOutputFallibleRetrier() }
        task = createTask(repeatDelay: repeatDelay, retrierBuilder: self.retrierBuilder)
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

    @MainActor
    private func createRetrier() -> AnySingleOutputFallibleRetrier<Output> {
        let retrier = retrierBuilder()
        retrierSubject.send(retrier)
        return retrier
    }

    @MainActor
    private func send(completion: Subscribers.Completion<Error>) async {
        sendSync(completion: completion)
    }

    private func sendSync(completion: Subscribers.Completion<Error>) {
        completionSubject.send(completion)
        completionSubject.send(completion: .finished)
        retrierSubject.send(completion: .finished)
    }

    private func createTask(repeatDelay: TimeInterval,
                            retrierBuilder: @escaping () -> AnySingleOutputFallibleRetrier<Output>) -> Task<Void, Error> {
        Task {
            while true {
                do {
                    // Ensure we don't start before any ongoing business on main actor is finished
                    await MainActor.run {}
                    if Task.isCancelled {
                        break
                    }
                    let retrier = await createRetrier()
                    _ = try await retrier.cancellableValue
                    if Task.isCancelled {
                        break
                    }
                    try? await Task.sleep(nanoseconds: nanoseconds(repeatDelay))
                } catch {
                    await send(completion: .failure(error))
                    return
                }
            }
            await send(completion: .finished)
        }
    }

    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Error> {
        let result: AnyPublisher<Result<Output, Error>, Error> = retrierSubject
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
            task?.cancel()
            sendSync(completion: .finished)
        }
    }
}
