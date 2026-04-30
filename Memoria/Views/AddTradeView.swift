//
//  AddTradeView.swift
//  Memoria

import SwiftUI
import SwiftData

struct AddTradeView: View {
    let portfolio: Portfolio

    @State private var viewModel = AddTradeViewModel()

    var body: some View {
        #if os(macOS)
        AddTradeView_macOS(viewModel: viewModel, portfolio: portfolio)
        #else
        AddTradeView_iOS(viewModel: viewModel, portfolio: portfolio)
        #endif
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    AddTradeView(portfolio: portfolio).preferredColorScheme(.dark)
}
