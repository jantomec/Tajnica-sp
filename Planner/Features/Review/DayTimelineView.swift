import SwiftUI

struct DayTimelineView: View {
    let entries: [CandidateTimeEntry]
    let selectedEntryID: CandidateTimeEntry.ID?
    let onSelect: (CandidateTimeEntry) -> Void

    private let hourHeight: CGFloat = 52
    private let timelineLeadingInset: CGFloat = 68
    private let paddingMinutes = 60
    private let minutesPerDay = 24 * 60

    var body: some View {
        let timeWindow = visibleTimeWindow

        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                timelineGrid(for: timeWindow)

                ForEach(entries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        timelineBlock(for: entry)
                    }
                    .buttonStyle(.plain)
                    .frame(
                        width: max(geometry.size.width - timelineLeadingInset, 0),
                        height: blockHeight(for: entry),
                        alignment: .topLeading
                    )
                    .offset(
                        x: timelineLeadingInset,
                        y: verticalOffset(for: entry, in: timeWindow)
                    )
                }
            }
            .frame(height: timelineHeight(for: timeWindow))
        }
        .frame(height: timelineHeight(for: timeWindow))
    }

    private var visibleTimeWindow: Range<Int> {
        guard !entries.isEmpty else {
            return 0..<minutesPerDay
        }

        let startMinutes = entries.map { minutesSinceMidnight(for: $0.start) }
        let endMinutes = entries.map {
            max(minutesSinceMidnight(for: $0.stop), minutesSinceMidnight(for: $0.start))
        }

        let paddedStart = max((startMinutes.min() ?? 0) - paddingMinutes, 0)
        let paddedEnd = min((endMinutes.max() ?? minutesPerDay) + paddingMinutes, minutesPerDay)

        let roundedStart = floorToHour(paddedStart)
        let roundedEnd = max(ceilToHour(paddedEnd), roundedStart + 60)

        return roundedStart..<min(roundedEnd, minutesPerDay)
    }

    private func timelineGrid(for timeWindow: Range<Int>) -> some View {
        let hourMarkers = Array(stride(from: timeWindow.lowerBound, through: timeWindow.upperBound, by: 60))

        return VStack(spacing: 0) {
            ForEach(hourMarkers, id: \.self) { minute in
                HStack(alignment: .top, spacing: 12) {
                    Text(hourLabel(for: minute))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 56, alignment: .trailing)

                    Rectangle()
                        .fill(Color.secondary.opacity(minute == timeWindow.upperBound ? 0 : 0.12))
                        .frame(height: minute == timeWindow.upperBound ? 0 : 1)
                        .padding(.top, 8)

                    Spacer(minLength: 0)
                }
                .frame(height: minute == timeWindow.upperBound ? 0 : hourHeight, alignment: .top)
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

    private func verticalOffset(for entry: CandidateTimeEntry, in timeWindow: Range<Int>) -> CGFloat {
        let minutesSinceWindowStart = minutesSinceMidnight(for: entry.start) - timeWindow.lowerBound
        return CGFloat(minutesSinceWindowStart) / 60 * hourHeight
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

    private func minutesSinceMidnight(for date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return (hour * 60) + minute
    }

    private func floorToHour(_ minutes: Int) -> Int {
        (minutes / 60) * 60
    }

    private func ceilToHour(_ minutes: Int) -> Int {
        ((minutes + 59) / 60) * 60
    }

    private func timelineHeight(for timeWindow: Range<Int>) -> CGFloat {
        CGFloat(timeWindow.upperBound - timeWindow.lowerBound) / 60 * hourHeight
    }

    private func hourLabel(for minute: Int) -> String {
        String(format: "%02d:00", minute / 60)
    }
}
