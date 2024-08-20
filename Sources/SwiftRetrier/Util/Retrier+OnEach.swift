import Combine

public extension Retrier {

    func onEach(handleEvent: @escaping (RetrierEvent<Output>) -> Void) -> Self {
        var subscription: AnyCancellable?
        subscription = publisher()
            .sink(receiveCompletion: { _ in
                subscription?.cancel()
            }, receiveValue: handleEvent)
        return self
    }
}
