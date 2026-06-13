import SwiftUI

/// A card showing a metric with an SF Symbol icon, value, unit, and label.
/// Used on the Dashboard overview and detail tabs.
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HStack {
        MetricCard(title: "Steps", value: "8,420", unit: "steps", systemImage: "shoeprints.fill", color: .green)
        MetricCard(title: "Calories", value: "320", unit: "kcal", systemImage: "flame.fill", color: .orange)
        MetricCard(title: "Exercise", value: "45", unit: "min", systemImage: "figure.run", color: .mint)
    }
    .padding()
}
