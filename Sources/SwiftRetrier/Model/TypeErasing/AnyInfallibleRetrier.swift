import Foundation

public class AnyInfallibleRetrier<Output>: AnyRetrier<Output, Never>, InfallibleRetrier {}

extension InfallibleRetrier {
    public func eraseToAnyInfallibleRetrier() -> AnyInfallibleRetrier<Output> {
        AnyInfallibleRetrier(self)
    }
}
