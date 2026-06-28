import SwiftUI
import Charts

struct ChartView: View {
    let points: [PricePoint]
    let range: TimeRange

    @State private var hoveredPoint: PricePoint?

    private var lineColor: Color {
        guard let first = points.first, let last = points.last else { return .accentColor }
        return last.price >= first.price ? .green : .red
    }

    private var minPrice: Double { points.map(\.price).min() ?? 0 }
    private var maxPrice: Double { points.map(\.price).max() ?? 0 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if points.isEmpty {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("暂无历史数据")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    // Fill area under line
                    ForEach(points) { pt in
                        AreaMark(
                            x: .value("时间", pt.marketTime),
                            y: .value("价格", pt.price)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [lineColor.opacity(0.15), lineColor.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Main line
                    ForEach(points) { pt in
                        LineMark(
                            x: .value("时间", pt.marketTime),
                            y: .value("价格", pt.price)
                        )
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }

                    // Hover rule
                    if let hp = hoveredPoint {
                        RuleMark(x: .value("选中", hp.marketTime))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                        PointMark(
                            x: .value("时间", hp.marketTime),
                            y: .value("价格", hp.price)
                        )
                        .symbolSize(40)
                        .foregroundStyle(lineColor)
                    }
                }
                .chartYScale(domain: (minPrice * 0.998)...(maxPrice * 1.002))
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { val in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(String(format: "%.1f", v))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { val in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                        AxisValueLabel {
                            if let d = val.as(Date.self) {
                                Text(axisLabel(d))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let loc):
                                    guard let frame = proxy.plotFrame else { break }
                                    let origin = geo[frame].origin
                                    let relX = loc.x - origin.x
                                    if let date: Date = proxy.value(atX: relX) {
                                        hoveredPoint = points.min {
                                            abs($0.marketTime.timeIntervalSince(date)) <
                                            abs($1.marketTime.timeIntervalSince(date))
                                        }
                                    }
                                case .ended:
                                    hoveredPoint = nil
                                }
                            }
                    }
                }

                // Hover tooltip
                if let hp = hoveredPoint {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "$%.2f", hp.price))
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                        Text(tooltipDate(hp.marketTime))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                    .padding(4)
                }
            }
        }
    }

    private func axisLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        switch range {
        case .oneDay: fmt.dateFormat = "HH:mm"
        case .oneWeek: fmt.dateFormat = "E"
        case .oneMonth: fmt.dateFormat = "M/d"
        }
        return fmt.string(from: date)
    }

    private func tooltipDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        switch range {
        case .oneDay: fmt.dateFormat = "HH:mm"
        case .oneWeek: fmt.dateFormat = "M/d HH:mm"
        case .oneMonth: fmt.dateFormat = "M/d"
        }
        return fmt.string(from: date)
    }
}
