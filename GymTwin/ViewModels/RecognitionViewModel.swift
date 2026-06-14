import Foundation
import SwiftData

// MARK: - Recognition Phase

/// State machine for the scan → recognize → recommend flow.
enum RecognitionPhase: Equatable {
    case idle
    case scanning
    case recognized(MachineDefinition)
    case notFound(String)
    case error(String)

    static func == (lhs: RecognitionPhase, rhs: RecognitionPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.recognized(let a), .recognized(let b)): return a == b
        case (.notFound(let a), .notFound(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - RecognitionViewModel

/// Drives the scan → recognize → coach-suggest → start-training flow.
///
/// Lifecycle:
/// 1. View calls `bind(_:)` once in `.task`.
/// 2. Hardware layers (QRScannerView, NFCService, manual field) call `handle(rawCode:)`.
/// 3. ViewModel resolves the code via `MachineRecognitionService` + `LocalMachineRepository`,
///    looks up the user's linked `Machine`, computes a `SetRecommendation`, and exposes
///    `recognizedDefinition`, `linkedMachine`, and `suggestion`.
/// 4. "Start Training" calls `startTraining()` which ensures a Machine exists in the
///    user's gym and fires `AppRouter.startWorkout(machineID:)`.
@Observable @MainActor
final class RecognitionViewModel {

    // MARK: - Published state

    private(set) var phase: RecognitionPhase = .idle
    private(set) var recognizedDefinition: MachineDefinition?
    private(set) var linkedMachine: Machine?
    private(set) var suggestion: SetRecommendation?

    // MARK: - Internal

    private var context: ModelContext?
    private var router: AppRouter?

    private let repository: any MachineRepository = LocalMachineRepository()

    // MARK: - Bind

    func bind(_ context: ModelContext, router: AppRouter) {
        self.context = context
        self.router = router
    }

    // MARK: - Handle raw code (from QR / NFC / manual entry)

    func handle(rawCode: String) async {
        phase = .scanning

        // 1. Parse — MachineRecognitionService normalises QR/NFC payloads to a bare code.
        guard let code = MachineRecognitionService.parseMachineCode(from: rawCode) else {
            phase = .notFound(rawCode)
            return
        }

        // 2. Catalog lookup
        let definition: MachineDefinition?
        do {
            definition = try await repository.machine(forCode: code)
        } catch {
            phase = .error(error.localizedDescription)
            return
        }

        guard let def = definition else {
            phase = .notFound(code)
            return
        }

        recognizedDefinition = def

        // 3. Find linked user Machine (by machineCode)
        let machine = fetchMachine(forCode: def.machineCode)
        linkedMachine = machine

        // 4. Coach suggestion — only if the user already has a Machine (has history)
        if let machine, let ctx = context {
            let coach = CoachService(context: ctx)
            suggestion = coach.nextSet(forMachineID: machine.id, goal: .muscleGain)
        } else {
            suggestion = nil
        }

        phase = .recognized(def)
    }

    // MARK: - Reset

    func reset() {
        phase = .idle
        recognizedDefinition = nil
        linkedMachine = nil
        suggestion = nil
    }

    // MARK: - Start Training

    /// Ensures a user `Machine` exists for the recognized definition, then hands
    /// off to `AppRouter` to present the workout flow.
    func startTraining() {
        guard
            let def = recognizedDefinition,
            let ctx = context,
            let router
        else { return }

        // Re-use existing Machine or create one linked to this definition.
        let machine: Machine
        if let existing = linkedMachine {
            machine = existing
        } else {
            let newMachine = Machine(
                name: def.name,
                category: def.category,
                machineCode: def.machineCode
            )
            ctx.insert(newMachine)
            try? ctx.save()
            linkedMachine = newMachine
            machine = newMachine
        }

        router.startWorkout(machineID: machine.id)
    }

    // MARK: - Private helpers

    private func fetchMachine(forCode code: String) -> Machine? {
        guard let ctx = context else { return nil }
        let lower = code.lowercased()
        var descriptor = FetchDescriptor<Machine>(
            predicate: #Predicate { $0.machineCode == lower }
        )
        descriptor.fetchLimit = 1
        if let match = (try? ctx.fetch(descriptor))?.first { return match }

        // Also try original casing in case the stored code differs.
        var descriptor2 = FetchDescriptor<Machine>(
            predicate: #Predicate { $0.machineCode == code }
        )
        descriptor2.fetchLimit = 1
        return (try? ctx.fetch(descriptor2))?.first
    }
}

