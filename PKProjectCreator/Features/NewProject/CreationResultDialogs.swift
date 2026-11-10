import SwiftUI

// ProjectCreatedDialog is shown by New Project after a project is created (with or without a Premiere project).
// DriveNotConnectedDialog is still design-only (Xcode Previews): a disconnected drive disables Create Project instead.

struct ProjectCreatedDialog: View {
    let projectName: String
    let directoryCount: Int
    let premiereFilename: String?
    let location: String
    var onRevealInFinder: () -> Void = {}
    var onOpenInPremiere: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white, .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Created").font(.title3.weight(.semibold))
                    Text(projectName).foregroundStyle(.secondary)
                }
            }
            FormCard {
                VStack(spacing: 0) {
                    InfoRow(label: "Folders", value: "\(directoryCount) directories created (project root + \(directoryCount - 1) folders)")
                    if let premiereFilename {
                        InfoRow(label: "Premiere", value: "1 file copied: \(premiereFilename)")
                    }
                    InfoRow(label: "Location", value: location, monospaced: true)
                }
                .padding(.vertical, 4)
            }
            HStack {
                Button("Reveal in Finder", action: onRevealInFinder)
                if premiereFilename != nil {
                    Button("Open in Premiere Pro", action: onOpenInPremiere)
                }
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 560)
    }
}

struct DriveNotConnectedDialog: View {
    let volumeName: String
    let path: String
    var onChooseLocation: () -> Void = {}
    var onCancel: () -> Void = {}
    var onTryAgain: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.black, .yellow)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Can’t Create Project").font(.title3.weight(.semibold))
                    Text("The volume “\(volumeName)” isn’t connected, so the destination folder can’t be reached. Connect the drive and try again, or choose another location.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(path)
                .font(Theme.mono)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardFill, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.cardBorder))
            HStack {
                Button("Choose Location…", action: onChooseLocation)
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Try Again", action: onTryAgain)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 560)
    }
}

#Preview("State · Project created") {
    ProjectCreatedDialog(
        projectName: "2026 - 11 - 10 Event Develon",
        directoryCount: 19,
        premiereFilename: "2026 - 11 - 10 Event Develon.prproj",
        location: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/2026/2026 - 11 - 10 Event Develon/"
    )
    .preferredColorScheme(.dark)
}

#Preview("State · Drive not connected") {
    DriveNotConnectedDialog(volumeName: "KIOXIA", path: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/2026")
        .preferredColorScheme(.dark)
}
