import Foundation

func nanoseconds(_ time: TimeInterval) -> UInt64 {
    UInt64(time * 1_000_000_000)
}
