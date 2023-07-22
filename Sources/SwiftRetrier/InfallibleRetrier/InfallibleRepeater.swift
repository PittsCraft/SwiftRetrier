import Foundation
import Combine

public class InfallibleRepeater<Output>: Repeater, InfallibleRetrier, Cancellable {

    private let innerRepeater: FallibleRepeater<Output>
    private var subscription: AnyCancellable?

    public init<R>(repeatDelay: TimeInterval,
                   retrierBuilder: @escaping () -> R) where R: SingleOutputInfallibleRetrier, R.Output == Output {
        innerRepeater = FallibleRepeater(repeatDelay: repeatDelay, retrierBuilder: {
            let retrier = retrierBuilder().eraseToAnySingleOutputInfallibleRetrier()
            return InfallibleToFallibleSingleOutputRetrier(retrier: retrier)
        })
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

    public var attemptPublisher: AnyPublisher<Result<Output, Error>, Never> {
        innerRepeater
            .attemptPublisher
            .catch { _ in Empty() }
            .eraseToAnyPublisher()
    }

    public func cancel() {
        innerRepeater.cancel()
    }
}
