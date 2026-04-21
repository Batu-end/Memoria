import Foundation
import SwiftData

@Model
final class Execution {
    var id: UUID
    var date: Date
    var price: Double
    var quantity: Double
    var typeRaw: String // "Buy" or "Sell"
    
    // Relationship to parent Trade
    var trade: Trade?
    
    init(price: Double, quantity: Double, type: ExecutionType = .buy, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.price = price
        self.quantity = quantity
        self.typeRaw = type.rawValue
    }
    
    var type: ExecutionType {
        get { ExecutionType(rawValue: typeRaw) ?? .buy }
        set { typeRaw = newValue.rawValue }
    }
}

enum ExecutionType: String, CaseIterable, Codable {
    case buy = "Buy"
    case sell = "Sell"
}
