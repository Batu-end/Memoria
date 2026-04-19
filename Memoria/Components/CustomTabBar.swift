import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case analytics = "Stats"
    case trades = "Trades"
    case watchlist = "Watchlist"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .analytics: return "chart.bar.fill"
        case .trades: return "chart.bar.doc.horizontal.fill"
        case .watchlist: return "list.bullet"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab?
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                TabButton(tab: tab, isSelected: selectedTab == tab, animation: animation) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

struct TabButton: View {
    let tab: Tab
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 44, height: 28)
                
                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.blue)
                        .matchedGeometryEffect(id: "tab_text", in: animation)
                }
            }
            .frame(width: 80, height: 44)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                        .matchedGeometryEffect(id: "tab_pill", in: animation)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.05 : 1.0)
    }
}
