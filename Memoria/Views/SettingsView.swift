//
//  SettingsView.swift
//  Memoria
//
//  Created by Batu Demirtas on 4/17/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("startingBalance") private var startingBalance: Double = 1600.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Starting Balance", value: $startingBalance, format: .number)
                            .font(.system(.title3, design: .monospaced))
                    }
                } header: {
                    Label("Account", systemImage: "person.crop.circle")
                } footer: {
                    Text("Your starting balance is used to calculate your Net Liquidating Value (Total Cash) and overall portfolio performance.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
