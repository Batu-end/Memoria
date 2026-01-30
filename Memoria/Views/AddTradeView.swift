//
//  AddTradeView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//  File responsible for adding new stocks to the watchlist.

import SwiftUI
import SwiftData

struct AddTradeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // THE VIEWMODEL
    // The View owns the StateObject (or @State in iOS 17+) of the ViewModel.
    // The View's only job is to bind these values to UI components.
    @State private var viewModel = AddTradeViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark Background
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    // --- CUSTOM INPUT FIELDS ---
                    // This section creates the "Ticker" and "Price" boxes
                    // --- CUSTOM INPUT FIELDS ---
                    VStack(alignment: .leading, spacing: 20) {
                        // Ticker Field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TICKER")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            
                            TextField("Ticker", text: $viewModel.ticker)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        
                        // Price Field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ENTRY PRICE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            
                            TextField("0.00", text: $viewModel.priceString)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            (!viewModel.priceString.isEmpty && !viewModel.isValidPrice)
                                                ? AnyShapeStyle(.red)
                                                : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            if !viewModel.priceString.isEmpty && !viewModel.isValidPrice {
                                Text("Please enter a valid number")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(24)
                    
                    Spacer()
                    
                    // --- "ADD TO WATCHLIST" BUTTON ---
                    // This is the big gradient button at the bottom
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
                                LinearGradient(colors: !viewModel.isValidForm ? [.gray, .gray] : [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                            .opacity(!viewModel.isValidForm ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isValidForm)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("New Trade")
            // .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    AddTradeView()
        .preferredColorScheme(.dark)
}
