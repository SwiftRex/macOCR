import Combine
import CombineRex
import Foundation

enum Capture { }

extension Capture {
    enum Action {
        case capture(path: URL)
        case didCapture(path: URL)
        case captureError(error: ProcessTerminationError)
    }

    struct State: Codable, Equatable {
        let isCapturing: Bool
        let lastCaptureAttempt: Result<URL, ProcessTerminationError>?

        static var empty: State {
            .init(isCapturing: false, lastCaptureAttempt: nil)
        }
    }

    struct Dependency {
        let screenshot: (URL) -> Deferred<Future<URL, ProcessTerminationError>>
    }
}

extension Capture {
    static let reducer = Reducer<Action, State>.reduce { action, state in
        switch action {
        case .capture:
            state = .init(isCapturing: true, lastCaptureAttempt: nil)
        case let .didCapture(path):
            state = .init(isCapturing: false, lastCaptureAttempt: .success(path))
        case let .captureError(error):
            state = .init(isCapturing: false, lastCaptureAttempt: .failure(error))
        }
    }
}

extension Capture {
    static let middleware = EffectMiddleware<Action, Action, State, Dependency>.onAction { action, _, getState in
        guard case let .capture(path) = action else { return .doNothing }
        return Effect { context in
            context
                .dependencies
                .screenshot(path)
                .map { DispatchedAction(Action.didCapture(path: $0)) }
                .catch { Just(DispatchedAction(Action.captureError(error: $0))) }
        }
    }
}

public struct ProcessTerminationError: Codable, Equatable, Error {
    public let statusCode: Int
}

extension Capture.Dependency {
    static let live = Capture.Dependency { url in
        Deferred {
            Future { completion in
                let task = Process()
                task.launchPath = "/usr/sbin/screencapture"
                task.arguments = ["-i", "-r", url.path]
                task.terminationHandler = { process in
                    if process.terminationReason == .exit {
                        completion(.success(url))
                    } else {
                        completion(.failure(.init(statusCode: Int(process.terminationStatus))))
                    }
                }
                task.launch()
            }
        }
    }
}
