import SwiftUI

struct DiaryMessageBubble: View {
    let record: DiaryPromptRecord
    let bubbleWidth: CGFloat

    @State private var isExpanded = false
    @State private var collapsedHeight: CGFloat = 0
    @State private var expandedHeight: CGFloat = 0

    private let collapsedLineLimit = 4

    private var isCollapsible: Bool {
        expandedHeight > collapsedHeight + 1
    }

    private func updateCollapsedHeight(_ newHeight: CGFloat) {
        guard abs(collapsedHeight - newHeight) > 0.5 else { return }

        DispatchQueue.main.async {
            collapsedHeight = newHeight
        }
    }

    private func updateExpandedHeight(_ newHeight: CGFloat) {
        guard abs(expandedHeight - newHeight) > 0.5 else { return }

        DispatchQueue.main.async {
            expandedHeight = newHeight
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(record.rawText)
                .font(.body)
                .multilineTextAlignment(.leading)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .frame(maxWidth: bubbleWidth, alignment: .leading)

            if isCollapsible {
                Button(isExpanded ? "Less" : "More") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(alignment: .topLeading) {
            measurementView
        }
    }

    private var measurementView: some View {
        VStack(spacing: 0) {
            Text(record.rawText)
                .font(.body)
                .multilineTextAlignment(.leading)
                .lineLimit(collapsedLineLimit)
                .frame(maxWidth: bubbleWidth, alignment: .leading)
                .readCollapsedHeight(updateCollapsedHeight)

            Text(record.rawText)
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: bubbleWidth, alignment: .leading)
                .readExpandedHeight(updateExpandedHeight)
        }
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CollapsedHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ExpandedHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readCollapsedHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: CollapsedHeightPreferenceKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(CollapsedHeightPreferenceKey.self, perform: onChange)
    }

    func readExpandedHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ExpandedHeightPreferenceKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(ExpandedHeightPreferenceKey.self, perform: onChange)
    }
}
