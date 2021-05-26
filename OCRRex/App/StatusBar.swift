import AppKit
import SwiftUI

struct StatusBar: NSViewControllerRepresentable {
    let icon: NSImage
    let onTap: () -> Void

    func makeNSViewController(context: Context) -> some NSViewController {
        NSViewController()
    }

    func updateNSViewController(_ nsViewController: NSViewControllerType, context: Context) {
    }

    func makeCoordinator() -> StatusBarCoordinator {
        StatusBarCoordinator(icon: icon, onTap: onTap)
    }

    class StatusBarCoordinator {
        private let onTap: () -> Void
        private let statusBarItem: NSStatusItem

        init(icon: NSImage, onTap: @escaping () -> Void) {
            self.onTap = onTap
            statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
            statusBarItem.button?.image = icon
            statusBarItem.button?.target = self
            statusBarItem.button?.action = #selector(tapButton(_:))
        }

        @objc func tapButton(_ sender: AnyObject?) {
            onTap()
        }
    }
}
