//
//  MouseBackButton.swift
//  Memoria

import SwiftUI

#if os(macOS)
import AppKit

extension Notification.Name {
    static let mouseBackButton = Notification.Name("mouseBackButton")
}

func installMouseBackButtonMonitor() {
    NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
        if event.buttonNumber == 3 {
            NotificationCenter.default.post(name: .mouseBackButton, object: nil)
            return nil
        }
        return event
    }
}

extension View {
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

#else

func installMouseBackButtonMonitor() {}

extension View {
    func onMouseBackButton() -> some View { self }
}

#endif
