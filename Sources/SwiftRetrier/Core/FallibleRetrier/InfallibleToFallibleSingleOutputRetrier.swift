//
//  File.swift
//  
//
//  Created by Pierre Mardon on 22/07/2023.
//

import Foundation
import Combine

class InfallibleToFallibleSingleOutputRetrier<Output>: SingleOutputFallibleRetrier {

    private let retrier: AnySingleOutputInfallibleRetrier<Output>

    init(retrier: AnySingleOutputInfallibleRetrier<Output>) {
        self.retrier = retrier
    }

    func publisher() -> AnyPublisher<Result<Output, Error>, Error> {
        retrier.publisher()
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    var value: Output {
        get async throws {
            try await retrier.value
        }
    }

    func cancel() {
        retrier.cancel()
    }
}
