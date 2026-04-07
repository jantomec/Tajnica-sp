import SwiftUI

struct StatusBanner: View {
    enum Style {
        case info
        case success
        case warning
        case error

        var color: Color {
            switch self {
            case .info: .blue
            case .success: .green
            case .warning: .orange
            case .error: .red
            }
        }

        var iconName: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.iconName)
                .foregroundStyle(style.color)

            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(12)
        .background(style.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style.color.opacity(0.15), lineWidth: 1)
        )
    }
}
