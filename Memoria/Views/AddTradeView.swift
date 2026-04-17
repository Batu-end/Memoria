//
//  AddTradeView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//  Expanded form for logging a new trade with full details.

import SwiftUI
import SwiftData

struct AddTradeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = AddTradeViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark Background
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Core Details
                        VStack(alignment: .leading, spacing: 20) {
                            // Row: Ticker + Asset Type
                            HStack(spacing: 12) {
                                // Ticker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TICKER")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.gray)
                                    
                                    TextField("AAPL", text: $viewModel.ticker)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .textFieldStyle(.plain)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                        .overlay(inputBorder())
                                }
                                
                                // Asset Type Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TYPE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.gray)
                                    
                                    Picker("", selection: $viewModel.assetType) {
                                        ForEach(AssetType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(height: 46)
                                }
                                .frame(width: 140)
                            }
                            
                            // Side Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SIDE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                
                                Picker("", selection: $viewModel.side) {
                                    ForEach(TradeSide.allCases, id: \.self) { side in
                                        Text(side.rawValue).tag(side)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Row: Entry Price + Quantity
                            HStack(spacing: 12) {
                                InputField(
                                    label: "ENTRY PRICE",
                                    placeholder: "0.00",
                                    text: $viewModel.priceString,
                                    isValid: viewModel.isValidPrice
                                )
                                
                                InputField(
                                    label: "QUANTITY",
                                    placeholder: "100",
                                    text: $viewModel.quantityString,
                                    isValid: viewModel.isValidQuantity
                                )
                            }
                        }
                        .padding(24)
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 24)
                        
                        // Section 2: Strategy + Targets (Optional)
                        VStack(alignment: .leading, spacing: 20) {
                            Text("STRATEGY & TARGETS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            
                            // Strategy Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Strategy", selection: $viewModel.selectedStrategy) {
                                    Text("None").tag(Optional<TradeStrategy>.none)
                                    ForEach(TradeStrategy.allCases, id: \.self) { strat in
                                        Text(strat.rawValue).tag(Optional(strat))
                                    }
                                }
                                
                                if viewModel.selectedStrategy == .other {
                                    TextField("Custom strategy...", text: $viewModel.customStrategy)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                        .overlay(inputBorder())
                                }
                            }
                            
                            // Stop Loss + Take Profit
                            HStack(spacing: 12) {
                                InputField(
                                    label: "STOP LOSS",
                                    placeholder: "Optional",
                                    text: $viewModel.stopLossString,
                                    isValid: viewModel.isValidStopLoss
                                )
                                InputField(
                                    label: "TAKE PROFIT",
                                    placeholder: "Optional",
                                    text: $viewModel.takeProfitString,
                                    isValid: viewModel.isValidTakeProfit
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 24)
                        
                        // Section 3: Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            
                            TextEditor(text: $viewModel.notes)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 80)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(inputBorder())
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 20)
                        
                        // Submit Button
                        Button(action: {
                            viewModel.addTrade(context: modelContext)
                            dismiss()
                        }) {
                            Text("Open Trade")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: viewModel.isValidForm ? [.blue, .purple] : [.gray, .gray],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                                .opacity(viewModel.isValidForm ? 1 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.isValidForm)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("New Trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 600)
    }
    
    private func inputBorder() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
    }
}

// MARK: - Reusable Input Field

struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .textFieldStyle(.plain)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            (!text.isEmpty && !isValid)
                                ? AnyShapeStyle(.red)
                                : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                            lineWidth: 1
                        )
                )
            
            if !text.isEmpty && !isValid {
                Text("Enter a valid number")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    AddTradeView()
        .preferredColorScheme(.dark)
}
