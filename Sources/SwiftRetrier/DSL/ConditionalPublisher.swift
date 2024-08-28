import Foundation
import Combine

func conditionalPublisher<T>(
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
