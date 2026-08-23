import Testing

@testable import PulseCore

@Test func bmiKnownValue() {
    // 70 kg, 1.75 m → 22.86
    #expect(abs(FitnessMath.bmi(massKg: 70, heightM: 1.75) - 22.86) < 0.01)
}

@Test func bmiRejectsNonPositiveInput() {
    #expect(FitnessMath.bmi(massKg: 0, heightM: 1.75) == 0)
    #expect(FitnessMath.bmi(massKg: 70, heightM: 0) == 0)
}

@Test func bmiCategoriesUseWHOBands() {
    #expect(FitnessMath.bmiCategory(for: 18.4) == .underweight)
    #expect(FitnessMath.bmiCategory(for: 18.5) == .normal)
    #expect(FitnessMath.bmiCategory(for: 24.9) == .normal)
    #expect(FitnessMath.bmiCategory(for: 25.0) == .overweight)
    #expect(FitnessMath.bmiCategory(for: 29.9) == .overweight)
    #expect(FitnessMath.bmiCategory(for: 30.0) == .obese)
}

@Test func epleyOneRepMax() {
    // 100 kg × (1 + 5/30) = 116.67; formula applies at any rep count.
    #expect(abs(FitnessMath.oneRepMax(weightKg: 100, reps: 5) - 116.67) < 0.01)
    #expect(abs(FitnessMath.oneRepMax(weightKg: 100, reps: 1) - 103.33) < 0.01)
}

@Test func totalVolumeSumsSets() {
    // 10×60 + 10×62.5 + 8×65 = 600 + 625 + 520
    let sets = [(reps: 10, weightKg: 60.0), (reps: 10, weightKg: 62.5), (reps: 8, weightKg: 65.0)]
    #expect(FitnessMath.totalVolume(sets) == 1745)
}
