import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    var body: some View {
        GeometryReader { geometry in
            if appModel.diaryPromptHistory.isEmpty {
                ContentUnavailableView(
                    "No Prompts Yet",
                    systemImage: "book.closed",
                    description: Text("Processed prompts will appear here once you send them.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appModel.diaryFeedItems) { item in
                            switch item {
                            case let .dateSeparator(day):
                                DiaryDateSeparatorView(day: day)
                            case let .prompt(record):
                                DiaryMessageBubble(
                                    record: record,
                                    bubbleWidth: bubbleWidth(for: geometry.size.width)
                                )
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Diary")
    }

    private func bubbleWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth - 48, 240), 560)
    }
}
