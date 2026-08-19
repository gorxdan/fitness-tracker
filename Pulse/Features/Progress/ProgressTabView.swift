import SwiftUI

/// Progress charts screen. Build phase adds Swift Charts: volume by muscle group,
/// per-exercise 1RM trend, weight + BMI trend. Range switcher 1M/3M/1Y/All.
struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("Strength volume by muscle group", systemImage: "chart.bar.fill")
                Label("Per-exercise 1RM trend", systemImage: "chart.line.uptrend.xyaxis")
                Label("Weight & BMI trend", systemImage: "scalemass.fill")
            }
            .navigationTitle("Progress")
        }
    }
}
