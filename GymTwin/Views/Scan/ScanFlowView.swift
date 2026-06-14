import SwiftUI
import SwiftData
import AVFoundation

// MARK: - ScanFlowView

/// Full-screen scan flow presented as a `.fullScreenCover`.
/// Three entry paths, all routing through `RecognitionViewModel.handle(rawCode:)`:
/// 1. Live QR camera (when `QRScannerView.isAvailable`)
/// 2. NFC tap button (when `NFCService.isAvailable`)
/// 3. Manual code text field (always — simulator-safe fallback)
///
/// On recognition, slides up a premium card with coach suggestion and a
/// "Start Training" CTA that dismisses and hands off to `AppRouter`.
struct ScanFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var vm = RecognitionViewModel()
    @State private var manualCode = ""
    @State private var showManualEntry = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            GymBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close scanner")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)

                switch vm.phase {
                case .idle, .scanning:
                    scannerContent
                case .recognized(let def):
                    recognizedContent(def: def)
                case .notFound(let code):
                    notFoundContent(code: code)
                case .error(let message):
                    errorContent(message: message)
                }

                Spacer(minLength: 0)
            }
        }
        .task {
            vm.bind(modelContext, router: router)
        }
    }

    // MARK: - Scanner content

    @ViewBuilder
    private var scannerContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Header
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 52))
                    .foregroundStyle(DS.Palette.accentGradient)
                    .padding(.top, DS.Spacing.xl)

                Text("Scan Machine")
                    .font(.title2.weight(.bold))

                Text("Point at the QR code on the equipment, tap NFC, or enter the code manually.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xxl)
            }

            // Live QR camera
            if QRScannerView.isAvailable {
                QRScannerView { rawCode in
                    Task { await vm.handle(rawCode: rawCode) }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .strokeBorder(DS.Palette.accent.opacity(0.35), lineWidth: 1.5)
                )
                .padding(.horizontal, DS.Spacing.lg)
                .accessibilityLabel("Live QR code scanner")
            } else {
                cameraUnavailablePanel
            }

            // Secondary actions row
            HStack(spacing: DS.Spacing.md) {
                if NFCService.isAvailable {
                    nfcButton
                }
                manualEntryButton
            }
            .padding(.horizontal, DS.Spacing.lg)

            // Inline manual entry (expanded)
            if showManualEntry {
                manualEntryPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.Motion.spring, value: showManualEntry)
        .padding(.bottom, DS.Spacing.xl)
    }

    // MARK: - Camera unavailable panel

    private var cameraUnavailablePanel: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Camera / Scanner Unavailable")
                .font(.subheadline.weight(.semibold))
            Text("Use NFC or enter the machine code manually.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - NFC button

    private var nfcButton: some View {
        Button {
            // NFCService triggers a native NFC sheet; for now shows a placeholder.
            // The actual CoreNFC session would be wired here once the entitlement is added.
        } label: {
            Label("NFC", systemImage: "wave.3.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Palette.accentSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    DS.Palette.accentSecondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Palette.accentSecondary.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan via NFC")
    }

    // MARK: - Manual entry button

    private var manualEntryButton: some View {
        Button {
            showManualEntry.toggle()
        } label: {
            Label("Enter Code", systemImage: "keyboard")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    DS.Palette.accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Palette.accent.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enter machine code manually")
    }

    // MARK: - Manual entry panel

    private var manualEntryPanel: some View {
        VStack(spacing: DS.Spacing.md) {
            TextField("Machine code (e.g. sscp)", text: $manualCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospacedDigit())
                .padding(DS.Spacing.md)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Palette.accent.opacity(0.2), lineWidth: 1)
                )
                .submitLabel(.search)
                .onSubmit { submitManualCode() }

            Button {
                submitManualCode()
            } label: {
                Label("Find Machine", systemImage: "magnifyingglass")
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(manualCode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func submitManualCode() {
        let trimmed = manualCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task { await vm.handle(rawCode: trimmed) }
    }

    // MARK: - Recognized content

    @ViewBuilder
    private func recognizedContent(def: MachineDefinition) -> some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {

                // Success header
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(DS.Palette.success)
                        .padding(.top, DS.Spacing.xl)

                    Text("Machine Found")
                        .font(.title2.weight(.bold))
                }

                // Machine info card
                SurfaceCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(def.name)
                                    .font(.title3.weight(.bold))
                                if let manufacturer = def.manufacturer {
                                    Text(manufacturer)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            TagPill(
                                text: def.category,
                                systemImage: DS.Muscle.symbol(for: def.category),
                                tint: DS.Muscle.color(for: def.category)
                            )
                        }

                        if !def.muscleSummary.isEmpty {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(def.muscleSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let difficulty = def.difficulty {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "gauge.with.dots.needle.33percent")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(difficulty.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                // Coach suggestion card
                if let suggestion = vm.suggestion {
                    let weightText = formatWeight(suggestion.weight)
                    SuggestedSetCard(
                        machineName: def.name,
                        weightText: weightText,
                        repsText: "\(suggestion.reps)",
                        note: suggestion.note
                    )
                    .padding(.horizontal, DS.Spacing.lg)
                } else {
                    CoachInsightCard(
                        icon: "wand.and.stars",
                        title: "First session on \(def.name)",
                        message: "No history yet — your coach will personalise recommendations after your first set."
                    )
                    .padding(.horizontal, DS.Spacing.lg)
                }

                // Start Training CTA
                Button {
                    vm.startTraining()
                    dismiss()
                } label: {
                    Label("Start Training", systemImage: "play.fill")
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal, DS.Spacing.lg)

                // Try again
                Button("Scan Another") {
                    vm.reset()
                    manualCode = ""
                    showManualEntry = false
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Not found content

    private func notFoundContent(code: String) -> some View {
        calmFeedbackPanel(
            icon: "questionmark.circle",
            tint: DS.Palette.warning,
            title: "Machine Not Found",
            message: "\"\(code)\" isn't in the equipment library yet. Check the code and try again.",
            retryLabel: "Try Again"
        )
    }

    // MARK: - Error content

    private func errorContent(message: String) -> some View {
        calmFeedbackPanel(
            icon: "exclamationmark.triangle",
            tint: DS.Palette.heart,
            title: "Something Went Wrong",
            message: message,
            retryLabel: "Try Again"
        )
    }

    // MARK: - Shared calm feedback panel

    private func calmFeedbackPanel(
        icon: String,
        tint: Color,
        title: String,
        message: String,
        retryLabel: String
    ) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.title3.weight(.bold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xxl)
            }

            Button {
                vm.reset()
                manualCode = ""
                showManualEntry = false
            } label: {
                Text(retryLabel)
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", w)
            : String(format: "%.1f kg", w)
    }
}

// MARK: - QRScannerView

/// A UIViewRepresentable wrapper around `AVCaptureSession` that decodes QR codes.
/// Check `QRScannerView.isAvailable` before presenting — it returns `false` in the
/// Simulator because the Simulator has no camera hardware.
struct QRScannerView: UIViewRepresentable {

    let onCode: (String) -> Void

    /// `true` when a real camera is present (physical device only).
    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setup(in: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    // MARK: - PreviewView

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {

        private let onCode: (String) -> Void
        private var session: AVCaptureSession?
        private var didDeliver = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func setup(in view: PreviewView) {
            let session = AVCaptureSession()
            self.session = session

            guard
                let device = AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { return }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill

            // AVCaptureSession is internally thread-safe for start/stop but not
            // Sendable; start it off the main thread without tripping the
            // Swift 6 sending check.
            nonisolated(unsafe) let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }

        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard
                let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                let string = obj.stringValue
            else { return }

            Task { @MainActor in
                guard !self.didDeliver else { return }
                self.didDeliver = true
                self.session?.stopRunning()
                self.onCode(string)
            }
        }
    }
}

// MARK: - Preview

#Preview("ScanFlowView") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Machine.self, Workout.self, Gym.self, GymArea.self,
        configurations: config
    )
    return ScanFlowView()
        .modelContainer(container)
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}
