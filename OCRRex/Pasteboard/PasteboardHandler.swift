import AppKit
import Combine
import CombineRex
import Foundation

enum Pasteboard { }

extension Pasteboard {
    enum Action {
        case setString(String)
    }

    struct Dependency {
        let setString: (String) -> Void
    }
}

extension Pasteboard {
    static let middleware = EffectMiddleware<Action, Action, Void, Dependency>.onAction { action, _, _ in
        switch action {
        case let .setString(string):
            return .fireAndForget { context in
                context
                    .dependencies
                    .setString(string)
            }
        }
    }
}

extension Pasteboard.Dependency {
    static let live = Pasteboard.Dependency { string in
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
}
