import SwiftUI
import UIKit

/// Installs a non-blocking tap recognizer on the app window. Taps inside an
/// editable text view are ignored; every other tap ends text editing.
struct KeyboardDismissRecognizer: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
            guard let window = view?.window, let coordinator else { return }
            coordinator.installIfNeeded(in: window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { [weak uiView, weak coordinator = context.coordinator] in
            guard let window = uiView?.window, let coordinator else { return }
            coordinator.installIfNeeded(in: window)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        func installIfNeeded(in window: UIWindow) {
            guard installedWindow !== window else { return }
            uninstall()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            installedWindow = window
            self.recognizer = recognizer
        }

        func uninstall() {
            if let recognizer {
                installedWindow?.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            installedWindow = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var touchedView: UIView? = touch.view
            while let view = touchedView {
                if view is UITextField || view is UITextView {
                    return false
                }
                touchedView = view.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func dismissKeyboard() {
            // Let the tapped control finish its action first. Ending editing
            // synchronously can make the first tap on an alert button only
            // dismiss the keyboard instead of activating the button.
            DispatchQueue.main.async { [weak window = installedWindow] in
                window?.endEditing(true)
            }
        }
    }
}
