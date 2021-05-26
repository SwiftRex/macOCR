import Foundation

extension Optional {
    public func asResult<E: Error>(orError error: @autoclosure () -> E) -> Result<Wrapped, E> {
        map(Result.success) ?? .failure(error())
    }
}
