import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var vm: OilPriceViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notifications = NotificationService.shared

    @AppStorage("appLanguage") private var lang: String = "zh"
    @State private var launchAtLogin = false

    // Vehicle
    @AppStorage("vehicleTankGallons") private var tankGallons: Double = 15
    @AppStorage("vehicleWeeklyMiles") private var weeklyMiles: Double = 300
    @AppStorage("vehicleMPG")         private var mpg:         Double = 30

    // LLM
    @AppStorage("llmBaseURL")    private var llmBaseURL   = ""
    @AppStorage("llmModelName")  private var llmModelName = ""
    @State private var apiKeyField = ""
    @State private var llmTestResult: String?
    @State private var llmTesting = false

    // Alert thresholds
    @AppStorage("brentUpperAlertEnabled")   private var brentUpperEnabled   = false
    @AppStorage("brentUpperAlertThreshold") private var brentUpperThreshold = 0.0
    @AppStorage("brentLowerAlertEnabled")   private var brentLowerEnabled   = false
    @AppStorage("brentLowerAlertThreshold") private var brentLowerThreshold = 0.0

    @AppStorage("wtiUpperAlertEnabled")   private var wtiUpperEnabled   = false
    @AppStorage("wtiUpperAlertThreshold") private var wtiUpperThreshold = 0.0
    @AppStorage("wtiLowerAlertEnabled")   private var wtiLowerEnabled   = false
    @AppStorage("wtiLowerAlertThreshold") private var wtiLowerThreshold = 0.0

    @AppStorage("gasolineUpperAlertEnabled")   private var gasolineUpperEnabled   = false
    @AppStorage("gasolineUpperAlertThreshold") private var gasolineUpperThreshold = 0.0
    @AppStorage("gasolineLowerAlertEnabled")   private var gasolineLowerEnabled   = false
    @AppStorage("gasolineLowerAlertThreshold") private var gasolineLowerThreshold = 0.0

    @State private var bUpper = ""; @State private var bLower = ""
    @State private var wUpper = ""; @State private var wLower = ""
    @State private var gUpper = ""; @State private var gLower = ""

    var body: some View {
        Form {

            // ── Language ───────────────────────────────────────────────
            Section(loc("Language", "语言")) {
                Picker(loc("Language", "语言"), selection: $lang) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            // ── Auto Refresh ───────────────────────────────────────────
            Section(loc("Auto Refresh", "自动刷新")) {
                Picker(loc("Interval", "刷新频率"), selection: $vm.refreshIntervalMinutes) {
                    Text(loc("Every 15 min", "15 分钟")).tag(15)
                    Text(loc("Every 30 min", "30 分钟")).tag(30)
                    Text(loc("Every 60 min", "60 分钟")).tag(60)
                }
                .onChange(of: vm.refreshIntervalMinutes) { _, _ in vm.updateTimerInterval() }
            }

            // ── Startup ────────────────────────────────────────────────
            Section(loc("Startup", "启动")) {
                Toggle(loc("Launch at Login", "开机自动启动"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in setLaunchAtLogin(v) }
            }

            // ── Price Alerts ───────────────────────────────────────────
            Section(loc("Price Alerts", "价格提醒")) {
                notificationPermissionRow

                AlertSymbolSection(
                    symbolName: "Brent",
                    currentPrice: vm.brentPrice?.price,
                    upperEnabled: $brentUpperEnabled, upperText: $bUpper,
                    lowerEnabled: $brentLowerEnabled, lowerText: $bLower,
                    onCommit: {
                        brentUpperThreshold = Double(bUpper) ?? brentUpperThreshold
                        brentLowerThreshold = Double(bLower) ?? brentLowerThreshold
                        vm.resetAlertBaseline(for: .brent)
                    }
                )
                AlertSymbolSection(
                    symbolName: "WTI",
                    currentPrice: vm.wtiPrice?.price,
                    upperEnabled: $wtiUpperEnabled, upperText: $wUpper,
                    lowerEnabled: $wtiLowerEnabled, lowerText: $wLower,
                    onCommit: {
                        wtiUpperThreshold = Double(wUpper) ?? wtiUpperThreshold
                        wtiLowerThreshold = Double(wLower) ?? wtiLowerThreshold
                        vm.resetAlertBaseline(for: .wti)
                    }
                )
                AlertSymbolSection(
                    symbolName: loc("RBOB Gasoline", "RBOB 汽油"),
                    currentPrice: vm.gasolinePrice?.price,
                    upperEnabled: $gasolineUpperEnabled, upperText: $gUpper,
                    lowerEnabled: $gasolineLowerEnabled, lowerText: $gLower,
                    onCommit: {
                        gasolineUpperThreshold = Double(gUpper) ?? gasolineUpperThreshold
                        gasolineLowerThreshold = Double(gLower) ?? gasolineLowerThreshold
                        vm.resetAlertBaseline(for: .gasoline)
                    }
                )

                HStack {
                    Spacer()
                    Button(loc("Send Test Notification", "发送测试通知")) {
                        Task {
                            if notifications.authorizationStatus == .notDetermined {
                                _ = await notifications.requestPermission()
                            }
                            notifications.sendTest(for: .brent)
                        }
                    }
                    .disabled(notifications.authorizationStatus == .denied)
                }
            }

            // ── Vehicle ────────────────────────────────────────────────
            Section(loc("My Vehicle", "我的车辆")) {
                LabeledContent(loc("Tank Capacity", "油箱容量")) {
                    HStack {
                        TextField("15", value: $tankGallons, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                        Text(loc("gal", "加仑")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent(loc("Weekly Miles", "每周行驶")) {
                    HStack {
                        TextField("300", value: $weeklyMiles, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                        Text(loc("mi", "英里")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent(loc("Fuel Economy (MPG)", "平均油耗 (MPG)")) {
                    TextField("30", value: $mpg, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 70)
                }
                if mpg > 0 {
                    LabeledContent(
                        loc("Est. Weekly Usage", "估算周耗油"),
                        value: String(format: loc("%.1f gal", "%.1f 加仑"), weeklyMiles / mpg)
                    )
                }
            }

            // ── AI Server ─────────────────────────────────────────────
            Section(loc("AI Strategy Server", "AI 策略推理服务器")) {
                LabeledContent("Base URL") {
                    TextField("http://192.168.1.x:11434/v1", text: $llmBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent(loc("Model Name", "模型名称")) {
                    TextField("qwen2.5:14b", text: $llmModelName)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("API Key") {
                    SecureField(loc("Leave blank for local", "本地服务可留空"), text: $apiKeyField)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKeyField) { _, v in
                            KeychainHelper.setAPIKey(v.isEmpty ? nil : v)
                        }
                }

                HStack {
                    Button(loc("Test Connection", "测试连接")) {
                        llmTestResult = nil; llmTesting = true
                        Task {
                            let r = await LLMService.shared.testConnection()
                            switch r {
                            case .success(let msg): llmTestResult = "✓ " + msg
                            case .failure(let e):   llmTestResult = "✗ " + (e.errorDescription ?? loc("Failed", "失败"))
                            }
                            llmTesting = false
                        }
                    }
                    .disabled(llmBaseURL.isEmpty || llmModelName.isEmpty || llmTesting)
                    if llmTesting { ProgressView().scaleEffect(0.7) }
                    Spacer()
                }

                if let result = llmTestResult {
                    Text(result).font(.caption)
                        .foregroundStyle(result.hasPrefix("✓") ? .green : .red)
                }

                Text(loc(
                    "If the server uses http://, ensure NSAllowsArbitraryLoads is set in Info.plist. Rebuild required.",
                    "若服务器地址为 http://，请确认 Info.plist 已允许任意网络访问。重新 build 后生效。"
                ))
                .font(.caption).foregroundStyle(.tertiary)
            }

            // ── About ─────────────────────────────────────────────────
            Section(loc("About", "关于")) {
                LabeledContent(loc("Version", "版本"), value: "1.0.0 (MVP)")
                LabeledContent(loc("Data Source", "数据来源"),
                               value: loc("Yahoo Finance (delayed quotes)", "Yahoo Finance（延迟行情）"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("Disclaimer", "免责声明"))
                        .font(.caption).fontWeight(.medium)
                    Text(loc(
                        "Data is for personal reference only and may be delayed. Not financial or investment advice.",
                        "本应用所展示的油价数据仅供个人参考，存在延迟，不构成任何投资或交易建议。"
                    ))
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                Button(loc("Quit GasPulse", "退出 GasPulse")) { NSApplication.shared.terminate(nil) }
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 800)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(loc("Done", "完成")) { dismiss() }
            }
        }
        .onAppear {
            launchAtLogin = getLaunchAtLoginStatus()
            bUpper = brentUpperThreshold    > 0 ? String(format: "%.2f", brentUpperThreshold)    : ""
            bLower = brentLowerThreshold    > 0 ? String(format: "%.2f", brentLowerThreshold)    : ""
            wUpper = wtiUpperThreshold      > 0 ? String(format: "%.2f", wtiUpperThreshold)      : ""
            wLower = wtiLowerThreshold      > 0 ? String(format: "%.2f", wtiLowerThreshold)      : ""
            gUpper = gasolineUpperThreshold > 0 ? String(format: "%.2f", gasolineUpperThreshold) : ""
            gLower = gasolineLowerThreshold > 0 ? String(format: "%.2f", gasolineLowerThreshold) : ""
            apiKeyField = KeychainHelper.apiKey() ?? ""
            Task { await notifications.refreshStatus() }
        }
    }

    // MARK: - Notification permission row

    @ViewBuilder
    private var notificationPermissionRow: some View {
        HStack {
            switch notifications.authorizationStatus {
            case .authorized:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(loc("Notifications authorized", "通知权限已授权"))
                    .font(.caption).foregroundStyle(.secondary)
            case .denied:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(loc("Notifications denied", "通知权限已拒绝"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(loc("Open System Settings", "前往系统设置")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                }
                .font(.caption)
            default:
                Image(systemName: "bell.badge").foregroundStyle(.secondary)
                Text(loc("Notifications not authorized", "尚未授权通知"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(loc("Request Permission", "请求权限")) {
                    Task { _ = await notifications.requestPermission() }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Launch at Login

    private func getLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}

// MARK: - Per-symbol alert row

private struct AlertSymbolSection: View {
    let symbolName: String
    let currentPrice: Double?

    @Binding var upperEnabled: Bool
    @Binding var upperText: String
    @Binding var lowerEnabled: Bool
    @Binding var lowerText: String
    let onCommit: () -> Void

    @AppStorage("appLanguage") private var lang: String = "zh"

    private var upperValid: Bool { Double(upperText) ?? 0 > 0 }
    private var lowerValid: Bool { Double(lowerText) ?? 0 > 0 }
    private var bothValid: Bool {
        guard upperEnabled && lowerEnabled else { return true }
        return (Double(lowerText) ?? 0) < (Double(upperText) ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(symbolName).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                if let p = currentPrice {
                    Text(String(format: loc("Current $%.2f", "当前 $%.2f"), p))
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                Toggle(loc("Upper", "上限"), isOn: $upperEnabled)
                    .toggleStyle(.checkbox).disabled(!upperValid)
                    .onChange(of: upperEnabled) { _, _ in onCommit() }
                TextField(loc("Price", "价格"), text: $upperText)
                    .textFieldStyle(.roundedBorder).frame(width: 80)
                    .onChange(of: upperText) { _, _ in
                        if let v = Double(upperText), v > 0 { onCommit() }
                        if upperEnabled && !upperValid { upperEnabled = false }
                    }
                Text(loc("alert above (USD)", "USD 以上提醒")).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Toggle(loc("Lower", "下限"), isOn: $lowerEnabled)
                    .toggleStyle(.checkbox).disabled(!lowerValid)
                    .onChange(of: lowerEnabled) { _, _ in onCommit() }
                TextField(loc("Price", "价格"), text: $lowerText)
                    .textFieldStyle(.roundedBorder).frame(width: 80)
                    .onChange(of: lowerText) { _, _ in
                        if let v = Double(lowerText), v > 0 { onCommit() }
                        if lowerEnabled && !lowerValid { lowerEnabled = false }
                    }
                Text(loc("alert below (USD)", "USD 以下提醒")).font(.caption).foregroundStyle(.secondary)
            }

            if !bothValid {
                Text(loc("Lower must be less than upper", "下限价格必须小于上限价格"))
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}
