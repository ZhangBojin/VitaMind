import SwiftUI

/// A generic bar sparkline chart for health metric samples.
/// Normalizes values within the chart height and renders as a gradient bar series.
struct HealthChart: View {
    let samples: [HealthSample]
    let color: Color
    var secondaryColor: Color? = nil

    var body: some View {
        let sorted = samples.sorted { $0.date < $1.date }
        let values = sorted.map(\.value)
        let maxVal = values.max() ?? 100
        let minVal = values.min() ?? 0
        let range = max(maxVal - minVal, 1)

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(sorted) { sample in
                    let height = max(4, (sample.value - minVal) / range * geometry.size.height)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [color, secondaryColor ?? color.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(2, (geometry.size.width / CGFloat(max(sorted.count, 1))) - 2))
                        .frame(height: height)
                }
            }
        }
        .frame(height: 80)
    }
}

#Preview {
    let samples = (0..<30).map { i in
        HealthSample(
            type: .heartRate,
            value: Double.random(in: 60...100),
            date: Date().addingTimeInterval(TimeInterval(-i * 600))
        )
    }
    HealthChart(samples: samples, color: .red, secondaryColor: .orange)
        .padding()
}
