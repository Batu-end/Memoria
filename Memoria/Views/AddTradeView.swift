//
//  AddTradeView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI

struct AddTradeView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var ticker = ""
    @State private var price: Double?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Trade Details")) {
                    TextField("Ticker (e.g. AAPL)", text: $ticker)
                        // .textInputAutocapitalization(.characters)
                    
                    TextField("Entry Price", value: $price, format: .number)
                        // .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(action: {
                        // TODO: Save Action
                        print("Add trade: \(ticker) at \(String(describing: price))")
                        dismiss()
                    }) {
                        Text("Add to Watchlist")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("New Trade")
//            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddTradeView()
}
