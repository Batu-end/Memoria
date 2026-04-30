//
//  StealthModifier.swift
//  Memoria

import SwiftUI

struct StealthModifier: ViewModifier {
    let condition: Bool
    let radius: CGFloat
    @AppStorage("stealthMode", store: .app) private var stealthMode = false

    func body(content: Content) -> some View {
        content
            .blur(radius: condition && stealthMode ? radius : 0)
            .animation(.easeInOut(duration: 0.2), value: stealthMode)
    }
}

extension View {
    func stealthable(_ condition: Bool = true, radius: CGFloat = 8) -> some View {
        modifier(StealthModifier(condition: condition, radius: radius))
    }
}
