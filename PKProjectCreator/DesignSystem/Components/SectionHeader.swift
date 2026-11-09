import SwiftUI

struct SectionHeader<Accessory: View>: View {
    private let title: String
    private let accessory: Accessory

    init(_ title: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.sectionTitle)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            accessory
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}
