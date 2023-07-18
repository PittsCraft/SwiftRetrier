import Foundation
import Combine

public class ConditionalInfallibleRetrier<T>: SingleOutputInfallibleRetrier, SingleOutputConditionalRetrier {


    private let innerRetrier: ConditionalFallibleRetrier<T>

    public init<P: Publisher<Bool, Never>>(policy: InfallibleRetryPolicyInstance, conditionPublisher: P, job: @escaping Job<T>) {
        self.innerRetrier = ConditionalFallibleRetrier(policy: policy.toFallibleRetryPolicy().instance(),
                                                       conditionPublisher: conditionPublisher,
                                                       job: job)
    }

    public var attemptPublisher: AnyPublisher<Result<T, Error>, Never> {
        innerRetrier.attemptPublisher
            .catch { _ in Empty() }
            .eraseToAnyPublisher()
    }

    public var value: T {
        get async throws {
            try await innerRetrier.value
        }
    }

    public func cancel() {
        innerRetrier.cancel()
    }
}

