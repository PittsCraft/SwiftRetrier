import Foundation
import Combine

public protocol InfallibleRetrier: Retrier where Failure == Never {}
