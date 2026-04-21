//
//  TraderPersonality.swift
//  Memoria

import SwiftUI

enum TraderPersonality: String, CaseIterable {
    case human    = "Regular Civilian"
    case guru     = "Finance Guru"
    case vampire  = "Vampire"
    case pirate   = "Pirate"
    case degen    = "Degen"
    case nightOwl = "Night Owl"

    var emoji: String {
        switch self {
        case .human:    return "🧑"
        case .guru:     return "💼"
        case .vampire:  return "🧛"
        case .pirate:   return "🏴‍☠️"
        case .degen:    return "🎰"
        case .nightOwl: return "🦉"
        }
    }

    var nameFont: Font {
        switch self {
        case .human:    return .system(size: 34, weight: .heavy,  design: .rounded)
        case .guru:     return .system(size: 34, weight: .bold,   design: .serif)
        case .vampire:  return .system(size: 34, weight: .bold,   design: .serif)
        case .pirate:   return .system(size: 34, weight: .black,  design: .serif)
        case .degen:    return .system(size: 34, weight: .heavy,  design: .monospaced)
        case .nightOwl: return .system(size: 34, weight: .light,  design: .serif)
        }
    }

    var nameColor: Color {
        switch self {
        case .human:    return .white
        case .guru:     return Color(red: 1.0,  green: 0.82, blue: 0.2)
        case .vampire:  return Color(red: 0.78, green: 0.04, blue: 0.04)
        case .pirate:   return Color(red: 0.92, green: 0.62, blue: 0.12)
        case .degen:    return Color(red: 0.08, green: 0.95, blue: 0.38)
        case .nightOwl: return Color(red: 0.72, green: 0.5,  blue: 1.0)
        }
    }

    var accentColor: Color {
        switch self {
        case .human:    return .cyan
        case .guru:     return Color(red: 1.0,  green: 0.82, blue: 0.2)
        case .vampire:  return Color(red: 0.78, green: 0.04, blue: 0.04)
        case .pirate:   return Color(red: 0.92, green: 0.62, blue: 0.12)
        case .degen:    return Color(red: 0.08, green: 0.95, blue: 0.38)
        case .nightOwl: return Color(red: 0.72, green: 0.5,  blue: 1.0)
        }
    }

    var isItalic: Bool { self == .vampire || self == .nightOwl }
}
