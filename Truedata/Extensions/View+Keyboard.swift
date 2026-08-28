//
//  View+Keyboard.swift
//  Truedata
//

import SwiftUI
import UIKit

// MARK: - Tap Gesture Recognizer Delegate for Dismissing Keyboard

private final class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGestureDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // If the tap was inside an interactive text input (UITextField, UITextView, etc.),
        // do not trigger dismissal so the user can switch focus or edit text without unintended dismiss.
        var view = touch.view
        while let current = view {
            let className = String(describing: type(of: current))
            if current is UITextField || current is UITextView || className.contains("TextField") || className.contains("TextView") || className.contains("TextEditor") || className.contains("TextInput") {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - UIWindow Extension for Global Tap-to-Dismiss

extension UIWindow {
    private static var keyboardTapGestureKey: UInt8 = 0

    func enableTapToDismissKeyboard() {
        // Prevent duplicate gesture recognizers
        if let existingGestures = gestureRecognizers {
            for gesture in existingGestures where gesture is KeyboardDismissTapGesture {
                return
            }
        }

        let tapGesture = KeyboardDismissTapGesture(target: self, action: #selector(handleKeyboardDismissTap))
        tapGesture.cancelsTouchesInView = false
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.delegate = KeyboardDismissGestureDelegate.shared
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleKeyboardDismissTap() {
        endEditing(true)
    }
}

private final class KeyboardDismissTapGesture: UITapGestureRecognizer {}

// MARK: - View Extension for Keyboard Helpers

extension View {
    /// Programmatically dismiss the software keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Adds a background tap gesture that dismisses the keyboard
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}
