//
//  TickerLogoView.swift
//  Memoria
//
//  Created by Memoria on 4/18/26.
//

import SwiftUI

struct TickerLogoView: View {
    let ticker: String
    var size: CGFloat = 40

    @AppStorage("monochromeLogos", store: .app) private var monochromeLogos: Bool = false
    
    // Hash the first letter to consistently assign the same beautiful gradient to the same missing ticker
    private var gradientColors: [Color] {
        let firstLetter = ticker.first?.uppercased() ?? "A"
        let hashValue = firstLetter.utf8.first ?? 65
        
        switch hashValue % 5 {
        case 0: return [.blue, .purple]
        case 1: return [.orange, .red]
        case 2: return [.green, .mint]
        case 3: return [.cyan, .blue]
        default: return [.pink, .purple]
        }
    }
    
    var body: some View {
        let url = URL(string: "https://financialmodelingprep.com/image-stock/\(ticker.uppercased()).png")
        
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                // Successfully loaded logo
                image
                    .resizable()
                    .scaledToFit()
                    .grayscale(monochromeLogos ? 1.0 : 0.0)
                    .contrast(monochromeLogos ? 1.5 : 1.0)
                    .brightness(monochromeLogos ? 0.2 : 0.0)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else if phase.error != nil {
                // Network failed or 404 (Obscure Ticker/ETF) - Show Initials Fallback
                fallbackView
            } else {
                // Loading State
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: size, height: size)
                    .overlay(ProgressView().scaleEffect(0.5))
            }
        }
    }
    
    private var fallbackView: some View {
        Circle()
            .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .shadow(color: gradientColors[0].opacity(0.3), radius: 4)
            .overlay(
                Text(String(ticker.prefix(1)).uppercased())
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    HStack(spacing: 20) {
        TickerLogoView(ticker: "AAPL", size: 40)
        TickerLogoView(ticker: "TSLA", size: 40)
        TickerLogoView(ticker: "MSFT", size: 40)
        TickerLogoView(ticker: "RNDM", size: 40) // Will trigger fallback
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
