//
//  MouseBackButton.swift
//  Memoria

import SwiftUI
import AppKit

extension Notification.Name {
    static let mouseBackButton = Notification.Name("mouseBackButton")
}

/// Installs a process-wide NSEvent monitor for mouse button 3 (back).
/// Call once from ContentView.onAppear.
func installMouseBackButtonMonitor() {
    NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
        if event.buttonNumber == 3 {
            NotificationCenter.default.post(name: .mouseBackButton, object: nil)
            return nil // consume the event
        }
        return event
    }
}

extension View {
    /// Dismisses this view when the mouse back button is pressed.
    func onMouseBackButton() -> some View {
        modifier(MouseBackButtonModifier())
    }
}

private struct MouseBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .mouseBackButton)) { _ in
            dismiss()
        }
    }
}
