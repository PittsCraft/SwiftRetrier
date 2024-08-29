import Foundation
import Combine

public protocol JobRetrierBuilder: RetrierBuilder {
    associatedtype Value

    func handleRetrierEvents(receiveEvent: @escaping @Sendable @MainActor (RetrierEvent<Value>) -> Void) -> Self
}
