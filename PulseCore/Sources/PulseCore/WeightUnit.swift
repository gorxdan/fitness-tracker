import Foundation

/// Display unit for weights. Storage is always kg; conversion happens only at the UI edge.
public enum WeightUnit: String, CaseIterable, Sendable {
    case kilograms
    case pounds

    public var label: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        }
    }

    public func fromKg(_ kg: Double) -> Double {
        self == .kilograms ? kg : kg * 2.2046226218487757
    }

    public func toKg(_ value: Double) -> Double {
        self == .kilograms ? value : value / 2.2046226218487757
    }

    /// "82.5 kg" / "182.0 lb" — weights shown with one decimal.
    public func format(kg: Double, includeUnit: Bool = true) -> String {
        let value = fromKg(kg)
        let text = String(format: "%.1f", value)
        return includeUnit ? "\(text) \(label)" : text
    }
}
