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
    let actionView: AnyView?

    init(
        text: String,
        style: Style,
        actionView: AnyView? = nil
    ) {
        self.text = text
        self.style = style
        self.actionView = actionView
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: style.iconName)
                    .foregroundStyle(style.color)

                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let actionView {
                actionView
            }
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
