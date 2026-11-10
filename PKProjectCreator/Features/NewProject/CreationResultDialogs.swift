import SwiftUI

// ProjectCreatedDialog is shown by New Project after a project is created (with or without a Premiere project).
// A disconnected drive disables Create Project instead of showing a dialog.

struct ProjectCreatedDialog: View {
    let projectName: String
    let directoryCount: Int
    let premiereFilename: String?
    var resolveFilename: String?
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
                    if let resolveFilename {
                        InfoRow(label: "Resolve", value: "1 file copied: \(resolveFilename)")
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

#Preview("State · Project created") {
    ProjectCreatedDialog(
        projectName: "2026 - 11 - 10 Event Develon",
        directoryCount: 19,
        premiereFilename: "2026 - 11 - 10 Event Develon.prproj",
        location: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/2026/2026 - 11 - 10 Event Develon/"
    )
    .preferredColorScheme(.dark)
}

