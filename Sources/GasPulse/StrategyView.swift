import SwiftUI

// MARK: - Strategy Sheet

struct StrategyView: View {
    @EnvironmentObject var vm: OilPriceViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var lang: String = "en"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(.purple)
                Text(loc("AI Fill-up Strategy", "AI 加油策略", "Estrategia de repostaje IA")).font(.headline)
                Spacer()
                Button(loc("Done", "完成", "Listo")) { dismiss() }.buttonStyle(.borderless)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let plan = vm.strategyPlan {
                        StrategyPlanCard(plan: plan, vm: vm)
                    } else if vm.isGeneratingStrategy {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                Text(loc("Analyzing…", "正在分析…", "Analizando…"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else {
                        EmptyStrategyView()
                    }

                    if let err = vm.strategyError {
                        HStack {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Text(loc("For reference only. Not financial advice.",
                         "仅供参考，不构成投资建议"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    vm.generateStrategy()
                } label: {
                    if vm.isGeneratingStrategy {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label(vm.strategyPlan == nil
                              ? loc("Analyze", "生成策略", "Analizar")
                              : loc("Re-analyze", "重新生成", "Reanalizar"),
                              systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isGeneratingStrategy)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
    }
}

// MARK: - Plan Card

private struct StrategyPlanCard: View {
    let plan: StrategyPlan
    let vm: OilPriceViewModel
    @AppStorage("appLanguage") private var lang: String = "en"

    private var rbobPrice: Double { vm.gasolinePrice?.price ?? 0 }
    private var weeklyGal: Double {
        let miles = UserDefaults.standard.double(forKey: "vehicleWeeklyMiles").nonZero ?? 300
        let mpg   = UserDefaults.standard.double(forKey: "vehicleMPG").nonZero ?? 30
        return miles / mpg
    }
    private var estimatedExtra: Double {
        weeklyGal * rbobPrice * (plan.estimatedPriceChangePct / 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 8) {
                RecommendationBadge(rec: plan.recommendation)
                Spacer()
                ConfidenceChip(confidence: plan.confidence)
            }

            HStack(spacing: 4) {
                Image(systemName: trendIcon).foregroundStyle(trendColor)
                Text("\(loc("1-2 Week Trend:", "1-2 周趋势：", "Tendencia 1-2 sem.:")) \(plan.trend.displayText)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text(plan.outlook)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text(plan.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if rbobPrice > 0 && weeklyGal > 0 && plan.estimatedPriceChangePct != 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("Based on your vehicle usage", "基于你的用车情况", "Basado en tu vehículo"))
                        .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                    Text(vehicleText)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Text("\(loc("Generated", "生成于", "Generado")) \(relativeTime)")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Text("·").foregroundStyle(.tertiary).font(.system(size: 10))
                Text(plan.modelName)
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            if isStale {
                Text(loc("Analysis is over 24h old — consider re-analyzing.",
                         "信息已超过 24 小时，建议重新生成"))
                    .font(.system(size: 10)).foregroundStyle(.orange)
            }
        }
    }

    private var trendIcon: String {
        switch plan.trend {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable:  return "arrow.right"
        }
    }
    private var trendColor: Color {
        switch plan.trend {
        case .rising:  return .red
        case .falling: return .green
        case .stable:  return .secondary
        }
    }

    private var vehicleText: String {
        let pct   = plan.estimatedPriceChangePct
        let extra = abs(estimatedExtra)
        let currentLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        if currentLang == "zh" {
            let dir  = pct >= 0 ? "上涨" : "下跌"
            let sign = pct >= 0 ? "多花" : "少花"
            return String(format: "预计 RBOB %@约 %.1f%%，按每周 %.1f 加仑用量，下周油费约%@ $%.2f",
                          dir, abs(pct), weeklyGal, sign, extra)
        } else if currentLang == "es" {
            let dir  = pct >= 0 ? "subir" : "bajar"
            let sign = pct >= 0 ? "extra" : "ahorrado"
            return String(format: "RBOB est. %@ ~%.1f%%. A %.1f gal/semana, costo próxima semana ~$%.2f %@.",
                          dir, abs(pct), weeklyGal, extra, sign)
        } else {
            let dir  = pct >= 0 ? "rise" : "fall"
            let sign = pct >= 0 ? "extra" : "saved"
            return String(format: "RBOB est. to %@ ~%.1f%%. At %.1f gal/week, next week's fuel cost ~$%.2f %@.",
                          dir, abs(pct), weeklyGal, extra, sign)
        }
    }

    private var relativeTime: String {
        let diff = Date().timeIntervalSince(plan.generatedAt)
        let m = Int(diff / 60); let h = Int(diff / 3600)
        if diff < 60    { return loc("just now", "刚刚", "ahora") }
        if diff < 3600  { return loc("\(m)m ago", "\(m) 分钟前", "hace \(m)m") }
        if diff < 86400 { return loc("\(h)h ago", "\(h) 小时前", "hace \(h)h") }
        let fmt = DateFormatter(); fmt.dateFormat = "M/d HH:mm"
        return fmt.string(from: plan.generatedAt)
    }

    private var isStale: Bool { Date().timeIntervalSince(plan.generatedAt) > 86400 }
}

// MARK: - Sub-components

private struct RecommendationBadge: View {
    let rec: StrategyRecommendation

    private var color: Color {
        switch rec {
        case .fillNow: return .green
        case .wait:    return .orange
        case .neutral: return .secondary
        }
    }
    private var icon: String {
        switch rec {
        case .fillNow: return "fuelpump.fill"
        case .wait:    return "clock"
        case .neutral: return "minus.circle"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(rec.displayText).fontWeight(.semibold).foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ConfidenceChip: View {
    let confidence: StrategyConfidence
    @AppStorage("appLanguage") private var lang: String = "en"

    var body: some View {
        Text("\(loc("Confidence:", "置信度：", "Confianza:")) \(confidence.displayText)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct EmptyStrategyView: View {
    @AppStorage("appLanguage") private var lang: String = "en"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars").font(.largeTitle).foregroundStyle(.secondary)
            Text(loc(
                "Tap Analyze — AI will review recent\nBrent, WTI & RBOB futures trends\nand recommend when to fill up.",
                "点击「生成策略」，AI 将分析近期\nBrent、WTI 与 RBOB 期货走势，\n给出加油时机建议。",
                "Pulsa Analizar — la IA revisará\ntendencias recientes de Brent, WTI y RBOB\ny recomendará cuándo repostar."
            ))
            .multilineTextAlignment(.center)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
