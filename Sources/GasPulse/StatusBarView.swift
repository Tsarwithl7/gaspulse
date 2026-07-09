import SwiftUI

struct StatusBarView: View {
    @ObservedObject var vm: OilPriceViewModel
    @Binding var showSettings: Bool
    @Binding var showStrategy: Bool
    @AppStorage("appLanguage") private var lang: String = "zh"

    private var dot: Color {
        switch vm.dataStatus {
        case .normal:           return .green
        case .cached, .offline: return .orange
        case .failed, .noData:  return .red
        case .loading:          return .secondary
        }
    }

    private var statusLabel: String {
        switch vm.dataStatus {
        case .normal:  return loc("Live",     "数据正常")
        case .cached:  return loc("Cached",   "缓存数据")
        case .offline: return loc("Offline",  "离线")
        case .failed:  return loc("Failed",   "更新失败")
        case .noData:  return loc("No Data",  "无数据")
        case .loading: return loc("Loading…", "加载中…")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)

            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Normal refresh
            Button { vm.refresh() } label: {
                HStack(spacing: 3) {
                    if vm.isRefreshing && !vm.isForceRefreshing {
                        ProgressView().scaleEffect(0.55).frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10))
                    }
                    Text(loc("Refresh", "更新")).font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .disabled(vm.isRefreshing)
            .help(loc("Refresh (10s cooldown)", "普通更新（10 秒冷却）"))

            // Force refresh
            Button { vm.forceRefresh() } label: {
                HStack(spacing: 3) {
                    if vm.isForceRefreshing {
                        ProgressView().scaleEffect(0.55).frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                    }
                    Text(loc("Force", "强制更新")).font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .disabled(vm.isForceRefreshing)
            .help(loc("Bypass cooldown and fetch immediately", "忽略冷却，立即向数据源重新请求"))

            Divider().frame(height: 12)

            if vm.enabledAlertCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "bell.fill").font(.system(size: 10)).foregroundStyle(.orange)
                    Text("\(vm.enabledAlertCount)").font(.system(size: 10)).foregroundStyle(.orange)
                }
                .help(loc("\(vm.enabledAlertCount) price alert(s) active",
                          "已启用 \(vm.enabledAlertCount) 条价格提醒"))
            }

            // AI Strategy
            Button { showStrategy = true } label: {
                Image(systemName: vm.strategyPlan == nil ? "wand.and.stars" : "wand.and.stars.inverse")
                    .font(.system(size: 12))
                    .foregroundStyle(vm.strategyPlan != nil ? .purple : .secondary)
            }
            .buttonStyle(.borderless)
            .help(loc("AI Fill-up Strategy", "AI 加油策略"))

            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gear").font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help(loc("Settings", "设置"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
