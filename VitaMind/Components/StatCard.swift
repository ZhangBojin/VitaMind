import SwiftUI

/// A small card displaying a title, a colored value, and a unit.
/// Extracted from the original DashboardView for reuse across all tabs.
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        StatCard(title: "Avg", value: "72", unit: "BPM", color: .blue)
        StatCard(title: "Min", value: "58", unit: "BPM", color: .green)
        StatCard(title: "Max", value: "95", unit: "BPM", color: .orange)
    }
    .padding()
}
