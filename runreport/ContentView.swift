import SwiftUI

struct ContentView: View {

    @Environment(HealthKitManager.self) var healthKitManager

    var body: some View {
        NavigationStack {
            List {
                switch healthKitManager.authStatus {
                case .inProgress:
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                case .notDetermined:
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("HealthKit Authorization Required")
                            .font(.headline)
                        Text("Please authorize access to your Health data to view your running workouts.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Request Authorization") {
                            Task {
                                await healthKitManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                case .success:
                    if healthKitManager.isLoadingWorkouts {
                        ProgressView("Loading workouts...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if healthKitManager.runningWorkouts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            Text("No Running Workouts")
                                .font(.headline)
                            Text("No running workouts found for the current month.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        Section {
                            ForEach(healthKitManager.runningWorkouts) { workout in
                                RunningWorkoutRow(workout: workout)
                            }
                        } header: {
                            HStack {
                                Text("Running Workouts - \(currentMonthName)")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    Task {
                                        await healthKitManager.fetchRunningWorkouts()
                                    }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                        }
                    }
                case .error(let errorDescription):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.headline)
                        Text(errorDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await healthKitManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .navigationTitle("Run Report")
            .task {
                if case .success = healthKitManager.authStatus {
                    await healthKitManager.fetchRunningWorkouts()
                }
            }
            .refreshable {
                if case .success =  healthKitManager.authStatus {
                    await healthKitManager.fetchRunningWorkouts()
                }
            }
        }
    }
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}

struct RunningWorkoutRow: View {
    let workout: RunningWorkout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(workout.formattedDate)
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                Label(workout.formattedDistance, systemImage: "ruler")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Label(workout.formattedDuration, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
