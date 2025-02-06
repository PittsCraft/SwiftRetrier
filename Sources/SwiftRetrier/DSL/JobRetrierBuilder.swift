import Foundation
import Combine

public protocol JobRetrierBuilder: RetrierBuilder, Publisher {
    associatedtype Value

    func handleRetrierEvents(receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void) -> Self
}
