//
//  SummaryCard.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import SwiftUI

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
                .bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
