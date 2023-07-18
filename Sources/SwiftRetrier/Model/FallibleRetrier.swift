import Foundation
import Combine

public protocol FallibleRetrier: Retrier where Failure == Error {}
