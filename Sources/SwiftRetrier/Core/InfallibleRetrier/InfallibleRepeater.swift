import Foundation
import Combine

/// Repeats trials (retry sequences) separated by a fixed delay, using an underlying retrier.
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
///     // The only possible failure is cancellation
///     finish()
///     break
///   }
/// }
/// ```
///
/// On cancellation, the publisher finishes without emitting anything else.
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

    public convenience init<P>(
        policy: InfallibleRetryPolicy,
        conditionPublisher: P? = nil as AnyPublisher<Bool, Never>?,
        repeatDelay: TimeInterval,
        job: @escaping Job<Output>
    ) where P: Publisher, P.Output == Bool, P.Failure == Never {
        if let conditionPublisher {
            self.init(repeatDelay: repeatDelay,
                      retrierBuilder: {
                ConditionalInfallibleRetrier(policy: policy, conditionPublisher: conditionPublisher, job: job)
            })
        } else {
            self.init(repeatDelay: repeatDelay,
                      retrierBuilder: {
                SimpleInfallibleRetrier(policy: policy, job: job)
            })
        }
    }

    public func publisher() -> AnyPublisher<Result<Output, Error>, Never> {
        innerRepeater
            .publisher()
            .catch { _ in Empty() }
            .eraseToAnyPublisher()
    }

    public func cancel() {
        innerRepeater.cancel()
    }
}
