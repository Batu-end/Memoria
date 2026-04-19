//
//  SettingsView.swift
//  Memoria
//
//  Created by Batu Demirtas on 4/17/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trades: [Trade]
    @Query private var watchlistItems: [WatchlistItem]
    
    @AppStorage("startingBalance") private var startingBalance: Double = 0.0
    
    @State private var showingResetAlert = false
    @State private var confirmationText = ""
    
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
                
                Section {
                    Button(role: .destructive) {
                        confirmationText = ""
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Label("Erase All Data", systemImage: "trash")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account Data")
                        .foregroundStyle(.red)
                } footer: {
                    Text("This will permanently delete all your trades and watchlist history. This action cannot be undone.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .navigationTitle("Settings")
            .alert("Erase All Data?", isPresented: $showingResetAlert) {
                TextField("Type \"DELETE\" to confirm", text: $confirmationText)
                
                Button("Cancel", role: .cancel) { }
                
                Button("Erase Data", role: .destructive) {
                    if confirmationText == "DELETE" {
                        eraseAllData()
                    }
                }
                // While SwiftUI alerts sometimes don't dynamically disable buttons based on text fields,
                // we strictly check the string upon submission as the primary safeguard.
            } message: {
                Text("This action is permanent and cannot be undone. Please type DELETE to confirm.")
            }
        }
    }
    
    private func eraseAllData() {
        for trade in trades {
            modelContext.delete(trade)
        }
        for item in watchlistItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
