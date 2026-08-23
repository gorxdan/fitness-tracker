import Foundation

/// Pure domain math. No platform imports; unit-tested in PulseCoreTests.
/// Marked public so PulseCore also works consumed as a module, not only
/// compiled file-by-file into the app target.
public enum FitnessMath {
    public static func bmi(massKg: Double, heightM: Double) -> Double {
        guard massKg > 0, heightM > 0 else { return 0 }
        return massKg / (heightM * heightM)
    }

    public static func bmiCategory(for value: Double) -> BMICategory {
        switch value {
        case ..<18.5: .underweight
        case ..<25.0: .normal
        case ..<30.0: .overweight
        default: .obese
        }
    }

    /// Epley formula: weight × (1 + reps/30).
    public static func oneRepMax(weightKg: Double, reps: Int) -> Double {
        weightKg * (1 + Double(reps) / 30)
    }

    public static func volume(reps: Int, weightKg: Double) -> Double {
        Double(reps) * weightKg
    }

    /// Sum of reps × weight for all strength sets.
    public static func totalVolume(_ sets: [(reps: Int, weightKg: Double)]) -> Double {
        sets.reduce(0) { $0 + volume(reps: $1.reps, weightKg: $1.weightKg) }
    }
}

public enum BMICategory: String {
    case underweight, normal, overweight, obese

    public var label: String {
        switch self {
        case .underweight: "Underweight"
        case .normal: "Normal"
        case .overweight: "Overweight"
        case .obese: "Obese"
        }
    }
}
