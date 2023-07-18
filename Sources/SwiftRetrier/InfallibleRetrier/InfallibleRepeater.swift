import Foundation
import Combine

public class InfallibleRepeater<Output>: Repeater, InfallibleRetrier, Cancellable {

    private let retrierBuilder: () -> AnySingleOutputInfallibleRetrier<Output>

    private let retrierSubject = PassthroughSubject<AnySingleOutputInfallibleRetrier<Output>, Never>()
    private let completionSubject = CurrentValueSubject<Bool, Never>(false)
    private var task: Task<Void, Never>!

    public init<R>(repeatDelay: TimeInterval,
                   retrierBuilder: @escaping () -> R) where R: SingleOutputInfallibleRetrier, R.Output == Output {
        self.retrierBuilder = { retrierBuilder().eraseToAnySingleOutputInfallibleRetrier() }
        task = createTask(repeatDelay: repeatDelay, retrierBuilder: self.retrierBuilder)
    }

    public convenience init(repeatDelay: TimeInterval,
                            policy: InfallibleRetryPolicyInstance,
                            job: @escaping Job<Output>) {
        self.init(repeatDelay: repeatDelay,
                  retrierBuilder: {
            SimpleInfallibleRetrier(policy: policy, job: job)
        })
    }

    public convenience init<P>(
        repeatDelay: TimeInterval,
        policy: InfallibleRetryPolicyInstance,
        conditionPublisher: P,
        job: @escaping Job<Output>
    ) where P: Publisher, P.Output == Bool, P.Failure == Never {
        self.init(repeatDelay: repeatDelay,
                  retrierBuilder: {
            ConditionalInfallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
        })
    }

    @MainActor
    private func createRetrier() -> AnySingleOutputInfallibleRetrier<Output> {
        let retrier = retrierBuilder()
        retrierSubject.send(retrier)
        return retrier
    }

    @MainActor
    private func finish() async {
        finishSync()
    }

    private func finishSync() {
        retrierSubject.send(completion: .finished)
        completionSubject.send(true)
        completionSubject.send(completion: .finished)
    }

    private func createTask(
        repeatDelay: TimeInterval,
        retrierBuilder: @escaping () -> AnySingleOutputInfallibleRetrier<Output>
    ) -> Task<Void, Never> {
        Task {
            while true {
                // Ensure we don't start before any ongoing business on main actor is finished
                await MainActor.run {}
                if task.isCancelled {
                    break
                }
                let retrier = await createRetrier()
                do {
                    _ = try await retrier.value
                } catch {
                    break
                }
                if task.isCancelled {
                    break
                }
                do {
                    try await Task.sleep(nanoseconds: nanoseconds(repeatDelay))
                } catch {}
            }
            await finish()
        }
    }

    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Never> {
        retrierSubject
            .combineLatest(completionSubject)
            .map { retrier, completed in
                if completed {
                    return Empty<Result<Output, Error>, Never>()
                        .eraseToAnyPublisher()
                } else {
                    return retrier
                        .attemptPublisher
                        .eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            task.cancel()
            finishSync()
        }
    }
}
