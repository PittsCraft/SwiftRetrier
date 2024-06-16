import Foundation

func onMain(_ block: @escaping @Sendable () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}
