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
    
    // Capital Management States
    @State private var showCapitalSheet = false
    @State private var isDepositing = true
    @State private var adjustmentAmount: Double = 0.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("STARTING CAPITAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            
                            Text(startingBalance, format: .currency(code: "USD"))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        
                        HStack(spacing: 15) {
                            Button {
                                isDepositing = true
                                adjustmentAmount = 0
                                showCapitalSheet = true
                            } label: {
                                Label("Deposit", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                isDepositing = false
                                adjustmentAmount = 0
                                showCapitalSheet = true
                            } label: {
                                Label("Withdraw", systemImage: "minus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(.red)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 10)
                } header: {
                    Label("Portfolio Management", systemImage: "briefcase.fill")
                } footer: {
                    Text("Adjusting your capital will shift your entire equity curve. Use this to record external deposits or withdrawals from your broker.")
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
            .sheet(isPresented: $showCapitalSheet) {
                CapitalAdjustmentSheet(isDepositing: isDepositing) { amount in
                    if isDepositing {
                        startingBalance += amount
                    } else {
                        startingBalance -= amount
                    }
                }
            }
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

struct CapitalAdjustmentSheet: View {
    let isDepositing: Bool
    var onConfirm: (Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Image(systemName: isDepositing ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(isDepositing ? .green : .red)
                        .padding(.top, 20)
                    
                    Text(isDepositing ? "Deposit Funds" : "Withdraw Funds")
                        .font(.title2.bold())
                    
                    Text(isDepositing ? "Increase your baseline trading capital" : "Record a withdrawal from your trading account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                HStack {
                    Text("$")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    TextField("0.00", value: $amount, format: .number)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .focused($isFocused)
                        .multilineTextAlignment(.leading)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 250)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                
                Spacer()
                
                Button {
                    if let val = amount {
                        onConfirm(val)
                    }
                    dismiss()
                } label: {
                    Text("Confirm \(isDepositing ? "Deposit" : "Withdrawal")")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isDepositing ? Color.green : Color.red)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                .disabled(amount == nil || amount == 0)
                .opacity(amount == nil || amount == 0 ? 0.5 : 1.0)
                .padding(.bottom, 30)
            }
            .background(
                LinearGradient(
                    colors: [
                        (isDepositing ? Color.green : Color.red).opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .frame(width: 400, height: 450)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
