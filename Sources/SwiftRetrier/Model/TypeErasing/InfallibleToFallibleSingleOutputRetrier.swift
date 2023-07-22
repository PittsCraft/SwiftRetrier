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

    var attemptPublisher: AnyPublisher<Result<Output, Error>, Error> {
        retrier.attemptPublisher
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
