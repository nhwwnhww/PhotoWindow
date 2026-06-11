import SwiftUI

@main
struct PhotoWindowApp: App {
    @StateObject private var container = AppDependencyContainer.mock()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
                .preferredColorScheme(.dark)
        }
    }
}
