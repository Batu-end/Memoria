import SwiftUI
import SwiftData

struct ScalePositionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trade: Trade
    let livePrice: Double?
    
    @State private var type: ExecutionType = .buy
    @State private var priceString: String = ""
    @State private var quantityString: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    
    enum Field {
        case amount, quantity, price
    }
    @FocusState private var focusedField: Field?
    
    init(trade: Trade, livePrice: Double? = nil) {
        self.trade = trade
        self.livePrice = livePrice
        
        // Initial defaults
        let initialPrice = livePrice ?? trade.vwap ?? 0
        _priceString = State(initialValue: initialPrice > 0 ? String(format: "%.2f", initialPrice) : "")
        _quantityString = State(initialValue: "")
        _amountString = State(initialValue: "")
    }
    
    private var price: Double? { Double(priceString) }
    private var quantity: Double? { Double(quantityString) }
    
    private var isValid: Bool {
        guard let p = price, let q = quantity, p > 0, q > 0 else { return false }
        
        // If trimming, can't trim more than we have
        if type == .sell {
            return q <= trade.effectiveQuantity
        }
        
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(type == .buy ? "Scale In" : "Trim Position")
                    .font(.system(size: 16, weight: .bold))
                Text(trade.ticker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            
            Divider().background(Color.white.opacity(0.1))
            
            Form {
                Section {
                    Picker("Action", selection: $type) {
                        Text("Add (Buy)").tag(ExecutionType.buy)
                        Text("Trim (Sell)").tag(ExecutionType.sell)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .onChange(of: type) { _, _ in
                        // Clear inputs when switching types to avoid accidental overflow
                        quantityString = ""
                        amountString = ""
                    }
                }
                
                Section {
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", text: $priceString)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.blue)
                            .focused($focusedField, equals: .price)
                            .onChange(of: priceString) { _, _ in 
                                if focusedField == .price { syncFromQuantity() }
                            }
                    }
                    
                    HStack {
                        Text("Amount ($)")
                        Spacer()
                        TextField("0.00", text: $amountString)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amountString) { _, newValue in
                                if focusedField == .amount {
                                    syncFromAmount(newValue)
                                }
                            }
                        
                        if type == .sell {
                            Button("Max") {
                                let maxVal = trade.effectiveQuantity * (price ?? 0)
                                amountString = String(format: "%.2f", maxVal)
                                syncFromAmount(amountString)
                            }
                            .font(.caption2)
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                    
                    HStack {
                        Text("Quantity (Shares)")
                        Spacer()
                        TextField("0", text: $quantityString)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.blue)
                            .focused($focusedField, equals: .quantity)
                            .onChange(of: quantityString) { _, newValue in
                                if focusedField == .quantity {
                                    syncFromQuantity(newValue)
                                }
                            }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Execution Details")
                } footer: {
                    if type == .sell, let q = quantity, q == trade.effectiveQuantity {
                        Text("Note: Selling your entire remaining position will automatically close this trade.")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            
            // Stats Preview
            if let p = price, let q = quantity, p > 0, q > 0 {
                VStack(spacing: 4) {
                    let total = p * q
                    Text(type == .buy ? "Total Cost" : "Total Credit")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(total, format: .currency(code: "USD"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(type == .buy ? Color.primary : Color.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.03))
            }
            
            // Action Button
            Button(action: recordExecution) {
                HStack {
                    Image(systemName: type == .buy ? "plus.circle.fill" : "minus.circle.fill")
                    Text(type == .buy ? "Confirm Purchase" : "Confirm Sale")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? (type == .buy ? Color.blue : Color.orange) : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .padding()
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
        }
        .frame(width: 320, height: 500)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Sync Logic
    private func syncFromAmount(_ newValue: String) {
        let cleaned = newValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let amount = Double(cleaned), let p = price, p > 0 else { return }
        let calculatedQty = amount / p
        // Use up to 4 decimal places, but strip trailing zeros
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        
        if let newQtyString = formatter.string(from: NSNumber(value: calculatedQty)) {
            if quantityString != newQtyString {
                quantityString = newQtyString
            }
        }
    }
    
    private func syncFromQuantity(_ newValue: String? = nil) {
        let qStr = (newValue ?? quantityString).replacingOccurrences(of: ",", with: "")
        guard let q = Double(qStr), let p = price else { return }
        let calculatedAmount = q * p
        let newAmountString = String(format: "%.2f", calculatedAmount)
        if amountString != newAmountString {
            amountString = newAmountString
        }
    }
    
    private func recordExecution() {
        guard let p = price, let q = quantity else { return }
        
        let execution = Execution(price: p, quantity: q, type: type, date: date)
        trade.executions.append(execution)
        
        // Auto-close logic
        if trade.effectiveQuantity == 0 {
            trade.status = .closed
            trade.dateClosed = date
            trade.exitPrice = p // Use last sell price as master exit price
        }
        
        AnalyticsService.shared.log(
            type == .buy ? .tradeOpened : .tradeClosed,
            details: "Scaled \(type.rawValue) \(q) shares of \(trade.ticker) @ \(p)",
            context: modelContext
        )
        
        dismiss()
    }
}
