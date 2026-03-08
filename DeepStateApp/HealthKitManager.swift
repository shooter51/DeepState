import Foundation
import HealthKit
import DiveCore

@Observable
final class HealthKitManager {
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var diveWorkouts: [HKWorkout] = []

    private let healthStore = HKHealthStore()

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType()
        ]

        var typesToRead: Set<HKObjectType> = [
            HKWorkoutType.workoutType()
        ]

        // iOS 16+ underwater depth support
        if let depthType = HKQuantityType.quantityType(forIdentifier: .underwaterDepth) {
            typesToShare.insert(depthType)
            typesToRead.insert(depthType)
        }

        if let tempType = HKQuantityType.quantityType(forIdentifier: .waterTemperature) {
            typesToShare.insert(tempType)
            typesToRead.insert(tempType)
        }

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)

        let status = healthStore.authorizationStatus(for: HKWorkoutType.workoutType())
        await MainActor.run {
            self.authorizationStatus = status
        }
    }

    // MARK: - Save Dive Workout

    func saveDiveWorkout(session: DiveSession) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let startDate = session.startDate
        let endDate = session.endDate ?? startDate.addingTimeInterval(session.duration)

        let workout = HKWorkout(
            activityType: .underwaterDiving,
            start: startDate,
            end: endDate,
            duration: session.duration,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [
                "MaxDepth": session.maxDepth,
                "AvgDepth": session.avgDepth,
                "O2Percent": session.o2Percent,
                "GFLow": session.gfLow,
                "GFHigh": session.gfHigh
            ]
        )

        try await healthStore.save(workout)

        // Save depth samples if available
        let samples = (session.depthSamples ?? []).sorted { $0.timestamp < $1.timestamp }

        if let depthType = HKQuantityType.quantityType(forIdentifier: .underwaterDepth) {
            let depthSamples: [HKQuantitySample] = samples.map { sample in
                HKQuantitySample(
                    type: depthType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: sample.depth),
                    start: sample.timestamp,
                    end: sample.timestamp
                )
            }
            if !depthSamples.isEmpty {
                try await healthStore.addSamples(depthSamples, to: workout)
            }
        }

        // Save temperature samples if available
        if let tempType = HKQuantityType.quantityType(forIdentifier: .waterTemperature) {
            let tempSamples: [HKQuantitySample] = samples.compactMap { sample in
                guard let temp = sample.temperature else { return nil }
                return HKQuantitySample(
                    type: tempType,
                    quantity: HKQuantity(unit: .degreeCelsius(), doubleValue: temp),
                    start: sample.timestamp,
                    end: sample.timestamp
                )
            }
            if !tempSamples.isEmpty {
                try await healthStore.addSamples(tempSamples, to: workout)
            }
        }
    }

    // MARK: - Fetch Dive Workouts

    func fetchDiveWorkouts() async throws -> [HKWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .underwaterDiving)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (results as? [HKWorkout]) ?? []
                Task { @MainActor in
                    self.diveWorkouts = workouts
                }
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }
}
