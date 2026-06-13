import SwiftUI

/// A reusable empty state view for when no health data is available.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}

#Preview {
    EmptyStateView(
        title: "No Heart Rate Data",
        systemImage: "heart.slash",
        description: "Wear your Apple Watch or ensure HealthKit has heart rate data."
    )
}
