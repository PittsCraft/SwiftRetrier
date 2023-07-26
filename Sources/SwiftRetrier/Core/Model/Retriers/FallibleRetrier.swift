import Foundation
import Combine

public protocol FallibleRetrier: BaseRetrier where Failure == Error {}
