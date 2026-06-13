import SwiftUI

/// A reusable authorization prompt shown when HealthKit access has not been granted.
struct HealthAuthorizationView: View {
    var body: some View {
        ContentUnavailableView(
            "需要健康数据访问权限",
            systemImage: "heart.text.clipboard",
            description: Text("VitaMind 需要访问 Apple 健康中的数据。请打开健康 App 授予权限。")
        )
    }
}

#Preview {
    HealthAuthorizationView()
}
