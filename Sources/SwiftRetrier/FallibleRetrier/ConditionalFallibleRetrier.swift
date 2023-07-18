import Foundation
import Combine

public class ConditionalFallibleRetrier<Output>: SingleOutputFallibleRetrier, SingleOutputConditionalRetrier {

    private let retrierSubject = PassthroughSubject<SimpleRetrier<Output>, Never>()
    private let policy: FallibleRetryPolicyInstance
    private let job: Job<Output>

    private var conditionSubscription: AnyCancellable?
    private let conditionPublisher: AnyPublisher<Bool, Never>
    private var retrierTask: Task<Void, Error>?
    private var validTaskUuid: UUID?
    private var mainTask: Task<Output, Error>!
    private var continuation: UnsafeContinuation<Output, Error>?
    private var retriersSubscription: AnyCancellable?
    private var cancelled = false

    private let subject = PassthroughSubject<Result<Output, Error>, Error>()

    public init<P: Publisher<Bool, Never>>(policy: FallibleRetryPolicyInstance,
                                           conditionPublisher: P,
                                           job: @escaping Job<Output>) {
        self.policy = policy
        self.job = job
        self.conditionPublisher = conditionPublisher.onMain()
        bindPublishers()
        self.mainTask = createMainTask()
    }

    private func bindPublishers() {
        retriersSubscription = retrierSubject
            .combineLatest(conditionPublisher) { (retrier: SimpleRetrier<Output>, condition: Bool) -> AnyPublisher<Result<Output, Error>, Never> in
                if condition {
                    return retrier.attemptPublisher.neverComplete()
                }
                return Empty(completeImmediately: false).eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [unowned self] in
                subject.send($0)
            }
    }

    private func createMainTask() -> Task<Output, Error> {
        Task {
            try await withUnsafeThrowingContinuation { continuation in
                DispatchQueue.main.async { [self] in
                    self.continuation = continuation
                    guard !cancelled else {
                        handleCompletion(result: .failure(CancellationError()), uuid: nil)
                        return
                    }
                    scheduleRetrierTask()
                }
            }
        }
    }

    private func scheduleRetrierTask() {
        var lastCondition: Bool?
        conditionSubscription = conditionPublisher
            .removeDuplicates()
            .sink(
                receiveCompletion: { [self] completion in
                    if lastCondition != true {
                        // The task will never be executed anymore and continuation will never be called with a relevant
                        // output.
                        handleCompletion(result: .failure(RetryError.conditionPublisherCompleted), uuid: nil)
                    }
                },
                receiveValue:{ [self] condition in
                    lastCondition = condition
                    if condition {
                        let uuid = UUID()
                        validTaskUuid = uuid
                        retrierTask = createRetrierTask(previousTask: retrierTask, uuid: uuid)
                    } else {
                        validTaskUuid = nil
                        retrierTask?.cancel()
                        if retrierTask != nil {
                            // When a task was running, its output is inhibited by the condition
                            // in `bindPublishers`, thus we have to signal its cancellation this way
                            subject.send(.failure(CancellationError()))
                        }
                    }
                }
            )
    }

    private func createRetrierTask(previousTask: Task<Void, Error>?, uuid: UUID) -> Task<Void, Error> {
        Task {
            do {
                let retrier = await createRetrier()
                try Task.checkCancellation()
                let result = try await retrier.cancellableValue
                try Task.checkCancellation()
                await handleCompletion(result: .success(result), uuid: uuid)
            } catch {
                await handleCompletion(result: .failure(error), uuid: uuid)
                throw error
            }
        }
    }

    @MainActor
    private func createRetrier() -> SimpleRetrier<Output> {
        let retrier = SimpleRetrier(policy: policy, job: job)
        retrierSubject.send(retrier)
        return retrier
    }

    private func handleCompletion(result: Result<Output, Error>, uuid: UUID?) {
        guard uuid == nil || uuid == validTaskUuid else { return }
        defer {
            self.continuation = nil
        }
        conditionSubscription?.cancel()
        guard !cancelled else {
            subject.send(completion: .finished)
            continuation?.resume(throwing: CancellationError())
            return
        }
        switch result {
        case .success(let output):
            subject.send(completion: .finished)
            continuation?.resume(with: .success(output))
        case .failure(let failure):
            subject.send(completion: .failure(failure))
            continuation?.resume(throwing: failure)
        }
    }

    private func handleCompletion(result: Result<Output, Error>, uuid: UUID?) async {
        await MainActor.run {
            handleCompletion(result: result, uuid: uuid)
        }
    }

    public var value: Output {
        get async throws {
            try await mainTask.value
        }
    }

    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Error> {
        subject.eraseToAnyPublisher()
    }

    public func cancel() {
        onMain { [self] in
            cancelled = true
            mainTask.cancel()
            retrierTask?.cancel()
            handleCompletion(result: .failure(CancellationError()), uuid: nil)
        }
    }
}
