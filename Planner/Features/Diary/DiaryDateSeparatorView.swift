import SwiftUI

struct DiaryDateSeparatorView: View {
    let day: Date

    var body: some View {
        HStack(spacing: 12) {
            separatorLine

            Text(PlannerFormatters.diarySeparatorDateString(day))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            separatorLine
        }
        .padding(.vertical, 4)
    }

    private var separatorLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(maxWidth: .infinity)
            .frame(height: 1)
    }
}
