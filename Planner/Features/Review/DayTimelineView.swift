import SwiftUI

struct DayTimelineView: View {
    let entries: [CandidateTimeEntry]
    let selectedEntryID: CandidateTimeEntry.ID?
    let onSelect: (CandidateTimeEntry) -> Void

    private let hourHeight: CGFloat = 52
    private let blockWidth: CGFloat = 220

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                timelineGrid

                ForEach(entries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        timelineBlock(for: entry)
                    }
                    .buttonStyle(.plain)
                    .frame(width: blockWidth, height: blockHeight(for: entry), alignment: .topLeading)
                    .offset(x: 68, y: verticalOffset(for: entry))
                }
            }
            .frame(height: hourHeight * 24)
        }
        .frame(minHeight: 420, maxHeight: 620)
    }

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            ForEach(0...24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 12) {
                    Text(hourLabel(hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 56, alignment: .trailing)

                    Rectangle()
                        .fill(Color.secondary.opacity(hour == 24 ? 0 : 0.12))
                        .frame(height: hour == 24 ? 0 : 1)
                        .padding(.top, 8)

                    Spacer(minLength: 0)
                }
                .frame(height: hour == 24 ? 0 : hourHeight, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func timelineBlock(for entry: CandidateTimeEntry) -> some View {
        let isSelected = selectedEntryID == entry.id

        VStack(alignment: .leading, spacing: 3) {
            Text(PlannerFormatters.timeRange(start: entry.start, stop: entry.stop))
                .font(.caption.monospacedDigit())
                .lineLimit(1)

            if blockHeight(for: entry) > 36 {
                Text(entry.description.isBlank ? "Untitled" : entry.description)
                    .font(.caption.weight(.semibold))
                    .lineLimit(blockHeight(for: entry) > 74 ? 3 : 1)
            }
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(blockColor(for: entry), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.primary.opacity(0.4) : .clear, lineWidth: 2)
        }
        .shadow(color: blockColor(for: entry).opacity(0.2), radius: isSelected ? 4 : 1, y: 1)
    }

    private func verticalOffset(for entry: CandidateTimeEntry) -> CGFloat {
        let dayStart = entry.date
        let minutesSinceStart = entry.start.timeIntervalSince(dayStart) / 60
        return CGFloat(minutesSinceStart / 60) * hourHeight
    }

    private func blockHeight(for entry: CandidateTimeEntry) -> CGFloat {
        let hours = entry.duration / 3600
        return max(CGFloat(hours) * hourHeight, 24)
    }

    private func blockColor(for entry: CandidateTimeEntry) -> Color {
        if entry.hasErrors {
            return .red
        }

        if entry.hasWarnings {
            return .orange
        }

        return entry.source == .user ? .green : .blue
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}
