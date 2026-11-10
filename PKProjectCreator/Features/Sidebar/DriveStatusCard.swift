import SwiftUI

struct DriveStatusCard: View {
    let drives: [DriveInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(drives) { drive in
                if drive.id != drives.first?.id {
                    Divider().padding(.horizontal, 8)
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "externaldrive")
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Text(drive.name).bold()) · \(drive.role)")
                            .foregroundStyle(.primary)
                        StatusLabel(text: drive.state.label, kind: drive.state.kind)
                            .font(.caption)
                    }
                }
                .font(.callout)
                .padding(10)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
    }
}
