import Foundation
import Combine

extension Publisher where Output == Bool, Failure == Never {

    func combineWith(condition: AnyPublisher<Bool, Never>?) -> AnyPublisher<Bool, Never> {
        let condition = condition ?? Just(true).eraseToAnyPublisher()
        return condition
            .combineLatest(self) { $0 && $1 }
            .eraseToAnyPublisher()
    }
}
