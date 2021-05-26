import Combine
import Vision
import SwiftUI

@main
struct App: SwiftUI.App {
    @StateObject var store = Store(world: .live).asObservableViewModel(initialState: .initial)

    var body: some Scene {
        WindowGroup {
            StatusBar(icon: NSImage(systemSymbolName: "doc.text.fill.viewfinder", accessibilityDescription: nil)!) {
                store.dispatch(.performWholeProcess)
            }
        }
    }
}

extension App {
    enum Action {
        case performWholeProcess
        case capture(Capture.Action)
        case detection(TextDetection.Action)
        case pasteboard(Pasteboard.Action)
    }
}

extension App {
    struct State: Equatable {
        var capture: Capture.State
        var detection: TextDetection.State
        let temporaryFile = FileManager.default.temporaryDirectory.appendingPathComponent("ocr.png")

        static var initial: State {
            .init(capture: .empty, detection: .empty)
        }
    }
}

struct World {
    let capture: Capture.Dependency
    let detection: TextDetection.Dependency
    let pasteboard: Pasteboard.Dependency
}

extension World {
    static let live = World(capture: .live, detection: .live, pasteboard: .live)
}

extension App {
    static let reducer =
        Capture.reducer.lift(action: \App.Action.capture, state: \App.State.capture)
        <> TextDetection.reducer.lift(action: \.detection, state: \.detection)
}

extension App {
    static func middleware(world: World) -> ComposedMiddleware<Action, Action, State> {
        Capture.middleware.inject(world.capture).lift(action: \App.Action.capture, state: \App.State.capture)
        <> TextDetection.middleware.inject(world.detection).lift(action: \.detection, state: \.detection)
        <> Pasteboard.middleware.inject(world.pasteboard).lift(inputAction: \.pasteboard, outputAction: App.Action.pasteboard, state: { _ in })
        <> EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .performWholeProcess:
                return .just(.capture(.capture(path: getState().temporaryFile)))
            case let .capture(.didCapture(path)):
                return .just(.detection(.detect(image: path)))
            case let .detection(.didDetect(_, text)):
                return .just(.pasteboard(.setString(text)))
            default:
                return .doNothing
            }
        }
    }
}

import CombineRex
extension App {
    class Store: ReduxStoreBase<Action, State> {
        init(world: World) {
            super.init(
                subject: .combine(initialValue: .initial),
                reducer: App.reducer,
                middleware: App.middleware(world: world)
            )
        }
    }
}

// Prism
extension App.Action {
    public var capture: Capture.Action? {
        get {
            guard case let .capture(value) = self else { return nil }
            return value
        }
        set {
            guard case .capture = self, let newValue = newValue else { return }
            self = .capture(newValue)
        }
    }

    public var isCapture: Bool {
        self.capture != nil
    }
}

extension App.Action {
    public var detection: TextDetection.Action? {
        get {
            guard case let .detection(value) = self else { return nil }
            return value
        }
        set {
            guard case .detection = self, let newValue = newValue else { return }
            self = .detection(newValue)
        }
    }

    public var isDetection: Bool {
        self.detection != nil
    }
}

extension App.Action {
    public var pasteboard: Pasteboard.Action? {
        get {
            guard case let .pasteboard(value) = self else { return nil }
            return value
        }
        set {
            guard case .pasteboard = self, let newValue = newValue else { return }
            self = .pasteboard(newValue)
        }
    }

    public var isPasteboard: Bool {
        self.pasteboard != nil
    }
}
