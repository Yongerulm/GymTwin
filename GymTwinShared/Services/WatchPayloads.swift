import Foundation
import SwiftData

// MARK: - Transfer DTOs
//
// `@Model` objects are never sent across WatchConnectivity. Instead these
// plain `Codable` value types are encoded to JSON `Data`. They are the stable
// contract between the iOS and watchOS apps.

/// A machine as the watch needs to display and train it.
struct MachineDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var category: String
    var notes: String
    var areaName: String
    var settings: [MachineSettingDTO]
}

struct MachineSettingDTO: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var value: String
}

/// The full machine catalog pushed from iPhone to Watch.
struct GymCatalogDTO: Codable, Hashable {
    var gymName: String
    var machines: [MachineDTO]
    var generatedAt: Date
}

/// A completed workout sent from Watch to iPhone.
struct WorkoutDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var notes: String
    var exercises: [WorkoutExerciseDTO]
}

struct WorkoutExerciseDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var machineID: UUID
    var machineName: String
    var sets: [WorkoutSetDTO]
}

struct WorkoutSetDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var weight: Double
    var repetitions: Int
    var timestamp: Date
}

// MARK: - Model → DTO

extension MachineDTO {
    init(machine: Machine) {
        self.init(
            id: machine.id,
            name: machine.name,
            category: machine.category,
            notes: machine.notes,
            areaName: machine.area?.name ?? "",
            settings: machine.sortedSettings.map {
                MachineSettingDTO(id: $0.id, title: $0.title, value: $0.value)
            }
        )
    }
}

extension WorkoutDTO {
    init(workout: Workout) {
        self.init(
            id: workout.id,
            date: workout.date,
            duration: workout.duration,
            notes: workout.notes,
            exercises: workout.sortedExercises.map { exercise in
                WorkoutExerciseDTO(
                    id: exercise.id,
                    machineID: exercise.machineID,
                    machineName: exercise.machineName,
                    sets: exercise.sortedSets.map {
                        WorkoutSetDTO(id: $0.id, weight: $0.weight, repetitions: $0.repetitions, timestamp: $0.timestamp)
                    }
                )
            }
        )
    }
}

// MARK: - DTO → Model

extension WorkoutDTO {
    /// Materialises this DTO into a `Workout` graph. The caller is responsible
    /// for inserting the returned object into a `ModelContext` and saving.
    func makeWorkout() -> Workout {
        let workout = Workout(id: id, date: date, duration: duration, notes: notes)
        workout.exercises = exercises.enumerated().map { index, dto in
            let exercise = WorkoutExercise(
                id: dto.id,
                machineID: dto.machineID,
                machineName: dto.machineName,
                sortIndex: index
            )
            exercise.sets = dto.sets.enumerated().map { setIndex, setDTO in
                WorkoutSet(
                    id: setDTO.id,
                    weight: setDTO.weight,
                    repetitions: setDTO.repetitions,
                    timestamp: setDTO.timestamp,
                    sortIndex: setIndex
                )
            }
            return exercise
        }
        return workout
    }
}
