import Foundation
import Combine

public protocol InfallibleRetrier: BaseRetrier where Failure == Never {}
