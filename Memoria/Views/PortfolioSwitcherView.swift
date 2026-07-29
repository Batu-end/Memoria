//
//  PortfolioSwitcherView.swift
//  Memoria

import SwiftUI
import SwiftData

struct PortfolioSwitcherView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @AppStorage("selectedPortfolioID", store: .app) private var selectedIDString: String = ""

    @State private var showNewAlert = false
    @State private var newName = ""
    @State private var portfolioToDelete: Portfolio?
    @State private var portfolioToRename: Portfolio?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(portfolios) { portfolio in
                    HStack {
                        Text(portfolio.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedIDString == portfolio.id.uuidString {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedIDString = portfolio.id.uuidString
                        }
                        dismiss()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if portfolios.count > 1 {
                            Button(role: .destructive) {
                                portfolioToDelete = portfolio
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        Button {
                            portfolioToRename = portfolio
                            renameText = portfolio.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            portfolioToRename = portfolio
                            renameText = portfolio.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        if portfolios.count > 1 {
                            Button(role: .destructive) {
                                portfolioToDelete = portfolio
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        newName = ""
                        showNewAlert = true
                    } label: {
                        Label("New Portfolio", systemImage: "plus")
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Portfolios")
            .darkNavigationBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .alert("New Portfolio", isPresented: $showNewAlert) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let portfolio = Portfolio(name: trimmed, sortOrder: portfolios.count)
                    modelContext.insert(portfolio)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedIDString = portfolio.id.uuidString
                    }
                    dismiss()
                }
            }
            .alert("Rename Portfolio", isPresented: Binding(
                get: { portfolioToRename != nil },
                set: { if !$0 { portfolioToRename = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { portfolioToRename = nil }
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { portfolioToRename?.name = trimmed }
                    portfolioToRename = nil
                }
            }
            .alert("Delete Portfolio?", isPresented: Binding(
                get: { portfolioToDelete != nil },
                set: { if !$0 { portfolioToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let toDelete = portfolioToDelete {
                        if selectedIDString == toDelete.id.uuidString {
                            let next = portfolios.first { $0.id != toDelete.id }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedIDString = next?.id.uuidString ?? ""
                            }
                        }
                        LocalAttachmentService.shared.deleteImages(for: toDelete.trades)
                        modelContext.delete(toDelete)
                    }
                    portfolioToDelete = nil
                }
                Button("Cancel", role: .cancel) { portfolioToDelete = nil }
            } message: {
                if let p = portfolioToDelete {
                    Text("\"\(p.name)\" and all its trades will be permanently deleted.")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, minHeight: 260)
        #endif
    }
}
