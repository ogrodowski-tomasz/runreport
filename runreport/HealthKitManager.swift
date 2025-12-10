import HealthKit
import Foundation

struct RunningWorkout: Identifiable {
    let id: UUID
    let date: Date
    let distance: Double // in meters
    let duration: TimeInterval // in seconds
    
    var formattedDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 2
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@Observable
final class HealthKitManager {

    enum HealthDataAuthStatus {
        case notDetermined
        case inProgress
        case success
        case error(String)

        var requestButtonDisabled: Bool {
            switch self {
            case .notDetermined: false
            default: true
            }
        }
    }

    var authStatus: HealthDataAuthStatus = .notDetermined
    var runningWorkouts: [RunningWorkout] = []
    var isLoadingWorkouts = false

    private let healthStore = HKHealthStore()

    private let types: Set = [
        HKQuantityType.workoutType(),
        HKObjectType.activitySummaryType(),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningSpeed),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.heartRate)
    ]

    func requestAuthorization() async {
        authStatus = .inProgress
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = .error("Health Data not available on this device")
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
            authStatus = .success
        } catch {
            authStatus = .error(error.localizedDescription)
        }

    }

    func fetchRunningWorkouts() async {
        guard case .success = authStatus else {
            return
        }
        
        isLoadingWorkouts = true
        defer { isLoadingWorkouts = false }
        
        // Get current month's start and end dates
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }
        
        let startOfDay = calendar.startOfDay(for: startOfMonth)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
        
        // Create predicate for current month and running workouts
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, runningPredicate])
        
        // Create query
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: compoundPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { query, samples, error in
            if let error = error {
                print("Error fetching workouts: \(error.localizedDescription)")
                return
            }
            
            guard let hkWorkouts = samples as? [HKWorkout] else {
                return
            }
            
            let runningWorkouts = hkWorkouts.compactMap { workout -> RunningWorkout? in
                // Get distance
                guard let distanceSample = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) ?? HKQuantityType(.distanceWalkingRunning)),
                      let distance = distanceSample.sumQuantity()?.doubleValue(for: .meter()) else {
                    // Try alternative distance type
                    if let altDistance = workout.totalDistance?.doubleValue(for: .meter()) {
                        return RunningWorkout(
                            id: UUID(),
                            date: workout.startDate,
                            distance: altDistance,
                            duration: workout.duration
                        )
                    }
                    return nil
                }
                
                return RunningWorkout(
                    id: UUID(),
                    date: workout.startDate,
                    distance: distance,
                    duration: workout.duration
                )
            }

            DispatchQueue.main.async {
                self.runningWorkouts = runningWorkouts
            }
        }
        
        healthStore.execute(query)
    }

    func createAnchorDate() -> Date {
        // Set the arbitrary anchor date to Monday at 3:00 a.m.
        let calendar: Calendar = .current
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
        let offset = (7 + (anchorComponents.weekday ?? 0) - 2) % 7

        anchorComponents.day! -= offset
        anchorComponents.hour = 3

        let anchorDate = calendar.date(from: anchorComponents)!

        return anchorDate
    }

}
