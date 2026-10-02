import SwiftUI

@main
struct OffGridChatApp: App {
    @StateObject private var engine = MeshEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .onAppear { engine.start() }
        }
    }
}
