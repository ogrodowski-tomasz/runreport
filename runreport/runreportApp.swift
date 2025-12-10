import SwiftUI
import HealthKit

@main
struct runreportApp: App {
    @State private var healthKitManager = HealthKitManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .task {
                    await healthKitManager.requestAuthorization()
                }
        }
    }

}
