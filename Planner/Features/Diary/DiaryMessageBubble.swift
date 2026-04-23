import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct DiaryMessageBubble: View {
    let record: DiaryPromptRecord
    let bubbleWidth: CGFloat
    let onOpen: () -> Void

    @State private var isExpanded = false

    private let collapsedLineLimit = 4
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 12

    private var maxContentWidth: CGFloat {
        max(bubbleWidth - (horizontalPadding * 2), 0)
    }

    private var renderedLineCount: Int {
        Self.renderedLineCount(for: record.rawText, width: maxContentWidth)
    }

    private var isCollapsible: Bool {
        renderedLineCount > collapsedLineLimit
    }

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text(record.rawText)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isExpanded ? nil : collapsedLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isCollapsible {
                    Button(isExpanded ? "Less" : "More") {
                        isExpanded.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }

                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Image(systemName: "timeline.selection")
                        .font(.caption)
                    Text("Open timeline")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: maxContentWidth, alignment: .trailing)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture(perform: onOpen)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private static func renderedLineCount(for text: String, width: CGFloat) -> Int {
        guard width > 0, !text.isEmpty else { return 0 }

        let textStorage = NSTextStorage(
            attributedString: NSAttributedString(
                string: text,
                attributes: [.font: platformBodyFont]
            )
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        var lineCount = 0
        var glyphIndex = 0

        while glyphIndex < layoutManager.numberOfGlyphs {
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            glyphIndex = NSMaxRange(lineRange)
            lineCount += 1
        }

        return lineCount
    }

    private static var platformBodyFont: PlatformFont {
        #if canImport(AppKit)
        NSFont.preferredFont(forTextStyle: .body)
        #elseif canImport(UIKit)
        UIFont.preferredFont(forTextStyle: .body)
        #endif
    }
}

#if canImport(AppKit)
private typealias PlatformFont = NSFont
#elseif canImport(UIKit)
private typealias PlatformFont = UIFont
#endif
