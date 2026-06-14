import SwiftUI
import SwiftData
import PhotosUI

/// Add / edit form for a machine. Pass `machine: nil` to create, or a live
/// `Machine` instance to edit. Handles photo picking with downscaling,
/// dynamic settings rows, and area selection with inline "New Area" creation.
struct MachineEditView: View {

    // MARK: - Init

    private let editingMachine: Machine?
    private let initialArea: GymArea?

    init(machine: Machine? = nil, initialArea: GymArea? = nil) {
        self.editingMachine = machine
        self.initialArea = initialArea
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var model = MachineViewModel()

    // Fields
    @State private var name = ""
    @State private var category = ""
    @State private var notes = ""
    @State private var selectedArea: GymArea?
    @State private var imageData: Data?

    // Photo picker
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    // Dynamic settings
    @State private var settings: [DraftSetting] = []

    // New area inline creation
    @State private var showingNewAreaField = false
    @State private var newAreaName = ""

    // Validation
    @State private var nameError = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                infoSection
                areaSection
                settingsSection
            }
            .scrollContentBackground(.hidden)
            .background(DS.Palette.background)
            .navigationTitle(editingMachine == nil ? "New Machine" : "Edit Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                model.bind(modelContext)
                populateFromMachine()
            }
            .onChange(of: photoItem) { loadPhoto() }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        MachinePhotoPreview(imageData: imageData)
                    }
                    .buttonStyle(.plain)

                    if imageData != nil {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                imageData = nil
                                photoItem = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .background(Color.black.opacity(0.5), in: Circle())
                        }
                        .offset(x: 8, y: 8)
                        .accessibilityLabel("Remove photo")
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            .padding(.vertical, DS.Spacing.sm)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
    }

    /// The square photo well shown in the photo section. A standalone view so
    /// it can be used as a plain `Button` label (main-actor-safe), unlike a
    /// `PhotosPicker`'s `@Sendable` label closure.
    private struct MachinePhotoPreview: View {
        let imageData: Data?

        var body: some View {
            Group {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        DS.Palette.accentGradient
                        VStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Add Photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: imageData != nil)
            .accessibilityLabel(imageData != nil ? "Change photo" : "Add photo")
            .accessibilityHint("Opens photo library")
        }
    }

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Machine name", text: $name)
                    .font(.body.weight(.medium))
                    .onChange(of: name) {
                        if !name.isEmpty { nameError = false }
                    }
                if nameError {
                    Text("Name is required")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            TextField("Category (e.g. Chest, Back, Legs)", text: $category)
                .font(.body)

            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.body)
        } header: {
            Text("Details")
        }
    }

    private var areaSection: some View {
        Section {
            Picker("Area", selection: $selectedArea) {
                Text("None").tag(Optional<GymArea>.none)
                ForEach(model.areas) { area in
                    Text(area.name).tag(Optional(area))
                }
            }

            if showingNewAreaField {
                HStack {
                    TextField("New area name", text: $newAreaName)
                        .submitLabel(.done)
                        .onSubmit { commitNewArea() }
                    Button("Add") { commitNewArea() }
                        .disabled(newAreaName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundStyle(DS.Palette.accent)
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingNewAreaField.toggle()
                    if !showingNewAreaField { newAreaName = "" }
                }
            } label: {
                Label(
                    showingNewAreaField ? "Cancel New Area" : "Add New Area",
                    systemImage: showingNewAreaField ? "xmark.circle" : "plus.circle.fill"
                )
                .foregroundStyle(showingNewAreaField ? .secondary : DS.Palette.accent)
            }
        } header: {
            Text("Gym Area")
        }
    }

    private var settingsSection: some View {
        Section {
            ForEach($settings) { $setting in
                HStack(spacing: DS.Spacing.sm) {
                    VStack(spacing: DS.Spacing.xs) {
                        TextField("Label", text: $setting.title)
                            .font(.subheadline.weight(.medium))
                        TextField("Value", text: $setting.value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            settings.removeAll { $0.id == setting.id }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove setting \(setting.title)")
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .onMove { from, to in
                settings.move(fromOffsets: from, toOffset: to)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    settings.append(DraftSetting(title: "", value: ""))
                }
            } label: {
                Label("Add Setting", systemImage: "plus.circle.fill")
                    .foregroundStyle(DS.Palette.accent)
            }
        } header: {
            HStack {
                Text("Settings")
                Spacer()
                if !settings.isEmpty {
                    EditButton()
                        .font(.caption)
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        } footer: {
            Text("Store your personal machine adjustments: seat position, weight pin, handle height, etc.")
        }
    }

    // MARK: - Actions

    private func populateFromMachine() {
        if let machine = editingMachine {
            name = machine.name
            category = machine.category
            notes = machine.notes
            imageData = machine.imageData
            selectedArea = machine.area
            settings = machine.sortedSettings.map {
                DraftSetting(id: $0.id, title: $0.title, value: $0.value)
            }
        } else if let area = initialArea {
            selectedArea = area
        }
    }

    private func loadPhoto() {
        guard let item = photoItem else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let original = UIImage(data: data) else { return }
            let downsized = downsample(original, maxDimension: 1024)
            guard let jpeg = downsized.jpegData(compressionQuality: 0.8) else { return }
            await MainActor.run { imageData = jpeg }
        }
    }

    private func commitNewArea() {
        let trimmed = newAreaName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let area = model.addArea(name: trimmed) {
            selectedArea = area
        }
        newAreaName = ""
        showingNewAreaField = false
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            nameError = true
            return
        }

        if let machine = editingMachine {
            // Update existing
            model.updateMachine(
                machine,
                name: trimmedName,
                category: category.trimmingCharacters(in: .whitespaces),
                area: selectedArea,
                notes: notes.trimmingCharacters(in: .whitespaces),
                imageData: imageData
            )
            // Sync settings: remove old, add fresh from draft
            for setting in machine.sortedSettings {
                model.removeSetting(setting, from: machine)
            }
            for (index, draft) in settings.enumerated() {
                let trimmedTitle = draft.title.trimmingCharacters(in: .whitespaces)
                if !trimmedTitle.isEmpty {
                    let s = MachineSetting(title: trimmedTitle, value: draft.value, sortIndex: index)
                    s.machine = machine
                    machine.settings.append(s)
                    modelContext.insert(s)
                }
            }
            try? modelContext.save()
        } else {
            // Create new
            if let machine = model.addMachine(
                name: trimmedName,
                category: category.trimmingCharacters(in: .whitespaces),
                area: selectedArea,
                notes: notes.trimmingCharacters(in: .whitespaces),
                imageData: imageData
            ) {
                for (index, draft) in settings.enumerated() {
                    let trimmedTitle = draft.title.trimmingCharacters(in: .whitespaces)
                    if !trimmedTitle.isEmpty {
                        let s = MachineSetting(title: trimmedTitle, value: draft.value, sortIndex: index)
                        s.machine = machine
                        machine.settings.append(s)
                        modelContext.insert(s)
                    }
                }
                try? modelContext.save()
            }
        }

        dismiss()
    }

    // MARK: - Image helpers

    private func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Draft setting model

/// Transient in-memory draft used by the settings editor before committing to SwiftData.
private struct DraftSetting: Identifiable {
    var id: UUID = UUID()
    var title: String
    var value: String
}
