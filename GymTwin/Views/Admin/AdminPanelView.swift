import SwiftUI
import SwiftData

// MARK: - AdminPanelView

/// Password-protected admin panel. First entry sets a 4-digit passcode
/// (hashed with SHA-256, stored in AppStorage). Subsequent entries verify it.
/// Sections: Machine Library · QR / NFC Mapping · Sync · AI Rules.
struct AdminPanelView: View {

    init() {}

    @Environment(\.modelContext) private var modelContext
    @State private var model = AdminViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isUnlocked {
                    adminContent
                } else {
                    passcodeGate
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if model.isUnlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Lock", systemImage: "lock") { model.lock() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Palette.accent)
                    }
                }
            }
        }
        .task { model.bind(modelContext) }
    }

    // MARK: - Passcode gate

    private var passcodeGate: some View {
        PasscodeGateView(isFirstUse: model.isFirstUse, error: model.passcodeError) { code in
            model.submitPasscode(code)
        } onClearError: {
            model.clearPasscodeError()
        }
    }

    // MARK: - Admin content

    private var adminContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                machineLibrarySection
                qrNFCSection
                syncSection
                aiRulesSection
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xl)
        }
        .background(DS.Palette.background)
    }

    // MARK: - Machine Library

    @State private var showingAddMachine = false
    @State private var editingDef: MachineDefinition?

    private var machineLibrarySection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Machine Library",
                                 subtitle: "\(model.definitions.count) definitions",
                                 actionTitle: "+ Add",
                                 action: { showingAddMachine = true })

            if model.isLoadingDefs {
                SurfaceCard {
                    HStack {
                        ProgressView()
                        Text("Loading catalog…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(DS.Spacing.lg)
                }
            } else if model.definitions.isEmpty {
                SurfaceCard {
                    EmptyStateView(
                        icon: "wrench.and.screwdriver",
                        title: "No Definitions",
                        message: "Tap + Add to create the first machine definition.",
                        actionTitle: "Add Machine",
                        action: { showingAddMachine = true }
                    )
                }
            } else {
                SurfaceCard(padding: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.definitions) { def in
                            Button {
                                editingDef = def
                            } label: {
                                machineRow(def)
                            }
                            .buttonStyle(.plain)

                            if def.id != model.definitions.last?.id {
                                Divider()
                                    .padding(.leading, DS.Spacing.xl + DS.Spacing.lg)
                                    .opacity(0.12)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMachine) {
            MachineDefinitionFormView(definition: nil) { newDef in
                Task { await model.upsert(newDef) }
            }
        }
        .sheet(item: $editingDef) { def in
            MachineDefinitionFormView(definition: def) { updated in
                Task { await model.upsert(updated) }
            }
        }
    }

    @ViewBuilder
    private func machineRow(_ def: MachineDefinition) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(DS.Muscle.color(for: def.category).opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: DS.Muscle.symbol(for: def.category))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Muscle.color(for: def.category))
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(def.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: DS.Spacing.xs) {
                    Text(def.machineCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(DS.Palette.accent)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(def.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .accessibilityLabel("\(def.name), code \(def.machineCode), \(def.category)")
        .accessibilityHint("Tap to edit")
    }

    // MARK: - QR / NFC Mapping

    private var qrNFCSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("QR / NFC Mapping",
                                 subtitle: "How machine codes are encoded")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.lg) {
                    // Schema note
                    infoRow(
                        icon: "qrcode",
                        tint: DS.Palette.accentSecondary,
                        title: "QR URL Format",
                        body: "https://lfconnect.com/q?t=s&m=<code>\n\nReplace <code> with the machine's exact machineCode (e.g. \"sscp\")."
                    )

                    Divider().opacity(0.12)

                    infoRow(
                        icon: "wave.3.right",
                        tint: DS.Palette.rest,
                        title: "NFC NDEF Format",
                        body: "Write a URI record with the same URL:\nhttps://lfconnect.com/q?t=s&m=<code>\n\nUse any NFC writer app. The app scans both QR and NFC identically."
                    )

                    if !model.definitions.isEmpty {
                        Divider().opacity(0.12)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("Example URLs")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(model.definitions.prefix(5)) { def in
                                HStack(spacing: DS.Spacing.xs) {
                                    Text(def.machineCode)
                                        .font(.caption.monospaced().weight(.semibold))
                                        .foregroundStyle(DS.Palette.accent)
                                        .frame(width: 60, alignment: .leading)
                                    Text("https://lfconnect.com/q?t=s&m=\(def.machineCode)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .accessibilityLabel("Machine code \(def.machineCode): URL https://lfconnect.com/q?t=s&m=\(def.machineCode)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Sync",
                                 subtitle: "Push catalog to OpenSearch")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.lg) {
                    syncStatusRow

                    Button {
                        Task { await model.syncToOpenSearch() }
                    } label: {
                        HStack {
                            if model.syncStatus == .syncing {
                                ProgressView()
                                    .scaleEffect(0.85)
                                    .tint(.white)
                            }
                            Text(model.syncStatus == .syncing ? "Syncing…" : "Sync to OpenSearch")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(model.syncStatus == .syncing)
                    .accessibilityLabel("Sync machine catalog to OpenSearch")
                }
            }

            Text("Set OPENSEARCH_URL in the environment to enable remote sync. The app works fully offline without it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.xs)
        }
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(syncStatusColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: syncStatusIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(syncStatusColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(syncStatusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(syncStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sync status: \(syncStatusTitle). \(syncStatusMessage)")
    }

    private var syncStatusColor: Color {
        switch model.syncStatus {
        case .idle: return .secondary
        case .syncing: return DS.Palette.accent
        case .success: return DS.Palette.success
        case .notConfigured: return DS.Palette.warning
        case .failed: return DS.Palette.heart
        }
    }

    private var syncStatusIcon: String {
        switch model.syncStatus {
        case .idle: return "arrow.triangle.2.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .notConfigured: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var syncStatusTitle: String {
        switch model.syncStatus {
        case .idle: return "Ready"
        case .syncing: return "Syncing…"
        case .success(let n): return "Synced \(n) definitions"
        case .notConfigured: return "OpenSearch not configured"
        case .failed: return "Sync failed"
        }
    }

    private var syncStatusMessage: String {
        switch model.syncStatus {
        case .idle: return "No sync performed yet this session."
        case .syncing: return "Pushing definitions to OpenSearch…"
        case .success(let n): return "\(n) machine definitions uploaded successfully."
        case .notConfigured: return "Set OPENSEARCH_URL to enable remote sync."
        case .failed(let msg): return msg
        }
    }

    // MARK: - AI Rules

    private var aiRulesSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("AI Rules",
                                 subtitle: "Deterministic coach logic (read-only)")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.lg) {
                    aiRuleRow(
                        icon: "arrow.up.circle.fill",
                        tint: DS.Palette.success,
                        title: "Progressive Overload",
                        body: "Weight increases by +2.5 kg after two consecutive sessions at the same load where all target reps are completed."
                    )

                    Divider().opacity(0.12)

                    aiRuleRow(
                        icon: "arrow.down.circle.fill",
                        tint: DS.Palette.warning,
                        title: "Deload Trigger",
                        body: "A deload is recommended when weight drops in two or more consecutive sessions (regression), or when the same weight is repeated for three or more sessions without progression (stagnation)."
                    )

                    Divider().opacity(0.12)

                    aiRuleRow(
                        icon: "ruler.fill",
                        tint: DS.Palette.accent,
                        title: "Weight Rounding",
                        body: "All recommended weights are rounded to the nearest 2.5 kg increment to match standard plate increments."
                    )

                    Divider().opacity(0.12)

                    aiRuleRow(
                        icon: "chart.line.uptrend.xyaxis",
                        tint: DS.Palette.accentSecondary,
                        title: "Progression Action",
                        body: "Coach emits one of three actions: increase load (progressive overload), maintain (on track), or deload (fatigue / regression detected)."
                    )
                }
            }
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func infoRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(body)")
    }

    @ViewBuilder
    private func aiRuleRow(icon: String, tint: Color, title: String, body: String) -> some View {
        infoRow(icon: icon, tint: tint, title: title, body: body)
    }
}

// MARK: - PasscodeGateView

private struct PasscodeGateView: View {
    let isFirstUse: Bool
    let error: String?
    let onSubmit: (String) -> Void
    let onClearError: () -> Void

    @State private var digits: String = ""
    @FocusState private var isFocused: Bool

    private let dotCount = 4

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(DS.Palette.accentGradient)
                    .frame(width: 80, height: 80)
                Image(systemName: isFirstUse ? "lock.open.fill" : "lock.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            .shadow(color: DS.Palette.accent.opacity(0.35), radius: 16, x: 0, y: 8)

            // Title + subtitle
            VStack(spacing: DS.Spacing.sm) {
                Text(isFirstUse ? "Set Admin Passcode" : "Admin Access")
                    .font(.title2.weight(.bold))
                Text(isFirstUse
                     ? "Choose a 4-digit code to protect admin settings."
                     : "Enter your 4-digit admin code to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }

            // Dot indicators
            HStack(spacing: DS.Spacing.xl) {
                ForEach(0..<dotCount, id: \.self) { i in
                    Circle()
                        .fill(i < digits.count ? DS.Palette.accent : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .animation(DS.Motion.spring, value: digits.count)
                }
            }
            .accessibilityLabel("\(digits.count) of 4 digits entered")

            // Hidden secure field (drives keyboard)
            SecureField("", text: $digits)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .onChange(of: digits) { _, new in
                    onClearError()
                    let filtered = String(new.filter(\.isNumber).prefix(dotCount))
                    if filtered != new { digits = filtered }
                    if filtered.count == dotCount {
                        let submitted = filtered
                        digits = ""
                        onSubmit(submitted)
                    }
                }

            // Tap area to bring keyboard
            Button {
                isFocused = true
            } label: {
                Text("Tap here to enter code")
                    .font(.subheadline)
                    .foregroundStyle(DS.Palette.accent)
            }
            .accessibilityLabel("Activate passcode entry")

            // Error message
            if let error {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(DS.Palette.heart)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(DS.Palette.heart)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(DS.Motion.spring, value: error)
                .accessibilityLabel("Error: \(error)")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Palette.background)
        .onAppear { isFocused = true }
    }
}

// MARK: - MachineDefinitionFormView

/// Sheet for adding or editing a MachineDefinition.
private struct MachineDefinitionFormView: View {
    let definition: MachineDefinition?
    let onSave: (MachineDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var machineCode: String
    @State private var name: String
    @State private var manufacturer: String
    @State private var category: String
    @State private var movementPattern: String
    @State private var primaryMuscles: String   // comma-separated
    @State private var secondaryMuscles: String // comma-separated
    @State private var difficulty: String
    @State private var equipmentType: String

    private var isEditing: Bool { definition != nil }

    init(definition: MachineDefinition?, onSave: @escaping (MachineDefinition) -> Void) {
        self.definition = definition
        self.onSave = onSave
        _machineCode = State(initialValue: definition?.machineCode ?? "")
        _name = State(initialValue: definition?.name ?? "")
        _manufacturer = State(initialValue: definition?.manufacturer ?? "")
        _category = State(initialValue: definition?.category ?? "")
        _movementPattern = State(initialValue: definition?.movementPattern ?? "")
        _primaryMuscles = State(initialValue: definition?.primaryMuscles.joined(separator: ", ") ?? "")
        _secondaryMuscles = State(initialValue: definition?.secondaryMuscles.joined(separator: ", ") ?? "")
        _difficulty = State(initialValue: definition?.difficulty ?? "")
        _equipmentType = State(initialValue: definition?.equipmentType ?? "")
    }

    private var isValid: Bool {
        !machineCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    identitySection
                    muscleSection
                    metaSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .background(DS.Palette.background)
            .navigationTitle(isEditing ? "Edit Definition" : "Add Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.subheadline.weight(.semibold))
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Form sections

    private var identitySection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Identity")
            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: 0) {
                    formField("Machine Code", text: $machineCode, hint: "e.g. sscp", mono: true)
                        .disabled(isEditing) // code is immutable once set
                        .opacity(isEditing ? 0.5 : 1)
                    divider()
                    formField("Name", text: $name, hint: "e.g. Seated Chest Press")
                    divider()
                    formField("Manufacturer", text: $manufacturer, hint: "Optional")
                    divider()
                    formField("Category", text: $category, hint: "e.g. Chest, Back, Legs…")
                }
            }
        }
    }

    private var muscleSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Muscles",
                                 subtitle: "Comma-separated values")
            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: 0) {
                    formField("Primary Muscles", text: $primaryMuscles, hint: "e.g. Chest, Triceps")
                    divider()
                    formField("Secondary Muscles", text: $secondaryMuscles, hint: "e.g. Shoulders")
                }
            }
        }
    }

    private var metaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Details")
            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: 0) {
                    formField("Movement Pattern", text: $movementPattern, hint: "e.g. Push, Pull, Hinge")
                    divider()
                    formField("Difficulty", text: $difficulty, hint: "e.g. Beginner, Intermediate")
                    divider()
                    formField("Equipment Type", text: $equipmentType, hint: "e.g. Machine, Cable, Barbell")
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formField(_ label: String, text: Binding<String>, hint: String, mono: Bool = false) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(label)
                .font(.subheadline)
                .fixedSize()
            Spacer()
            TextField(hint, text: text)
                .multilineTextAlignment(.trailing)
                .font(mono ? .subheadline.monospaced() : .subheadline)
                .foregroundStyle(.primary)
                .accessibilityLabel(label)
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    @ViewBuilder
    private func divider() -> some View {
        Divider()
            .padding(.leading, DS.Spacing.md)
            .opacity(0.12)
    }

    private func muscleList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        let def = MachineDefinition(
            machineCode: machineCode.trimmingCharacters(in: .whitespaces),
            name: name.trimmingCharacters(in: .whitespaces),
            manufacturer: manufacturer.isEmpty ? nil : manufacturer.trimmingCharacters(in: .whitespaces),
            category: category.trimmingCharacters(in: .whitespaces),
            movementPattern: movementPattern.isEmpty ? nil : movementPattern.trimmingCharacters(in: .whitespaces),
            primaryMuscles: muscleList(primaryMuscles),
            secondaryMuscles: muscleList(secondaryMuscles),
            difficulty: difficulty.isEmpty ? nil : difficulty.trimmingCharacters(in: .whitespaces),
            equipmentType: equipmentType.isEmpty ? nil : equipmentType.trimmingCharacters(in: .whitespaces)
        )
        onSave(def)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AdminPanelView()
        .modelContainer(for: [Gym.self, Workout.self], inMemory: true)
        .preferredColorScheme(.dark)
}
