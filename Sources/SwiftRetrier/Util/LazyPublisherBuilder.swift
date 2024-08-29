import Foundation
import Combine

struct LazyPublisherBuilder<P: Publisher>: Publisher {
    typealias Output = P.Output
    typealias Failure = P.Failure

    let builder: () -> P

    func receive<S>(subscriber: S) where S : Subscriber, P.Failure == S.Failure, P.Output == S.Input {
        builder().receive(subscriber: subscriber)
    }
}
