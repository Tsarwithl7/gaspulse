import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var vm: OilPriceViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notifications = NotificationService.shared

    @AppStorage("appLanguage") private var lang: String = "en"
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
            Section(loc("Language", "语言", "Idioma")) {
                Picker(loc("Language", "语言", "Idioma"), selection: $lang) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
                .pickerStyle(.segmented)
            }

            // ── Auto Refresh ───────────────────────────────────────────
            Section(loc("Auto Refresh", "自动刷新", "Actualización auto.")) {
                Picker(loc("Interval", "刷新频率", "Intervalo"), selection: $vm.refreshIntervalMinutes) {
                    Text(loc("Every 15 min", "15 分钟", "Cada 15 min")).tag(15)
                    Text(loc("Every 30 min", "30 分钟", "Cada 30 min")).tag(30)
                    Text(loc("Every 60 min", "60 分钟", "Cada 60 min")).tag(60)
                }
                .onChange(of: vm.refreshIntervalMinutes) { _, _ in vm.updateTimerInterval() }
            }

            // ── Startup ────────────────────────────────────────────────
            Section(loc("Startup", "启动", "Inicio")) {
                Toggle(loc("Launch at Login", "开机自动启动", "Iniciar al encender"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in setLaunchAtLogin(v) }
            }

            // ── Price Alerts ───────────────────────────────────────────
            Section(loc("Price Alerts", "价格提醒", "Alertas de precio")) {
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
                    symbolName: loc("RBOB Gasoline", "RBOB 汽油", "Gasolina RBOB"),
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
                    Button(loc("Send Test Notification", "发送测试通知", "Enviar notificación de prueba")) {
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
            Section(loc("My Vehicle", "我的车辆", "Mi vehículo")) {
                LabeledContent(loc("Tank Capacity", "油箱容量", "Cap. del tanque")) {
                    HStack {
                        TextField("15", value: $tankGallons, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                        Text(loc("gal", "加仑", "gal")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent(loc("Weekly Miles", "每周行驶", "Millas semanales")) {
                    HStack {
                        TextField("300", value: $weeklyMiles, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                        Text(loc("mi", "英里", "mi")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent(loc("Fuel Economy (MPG)", "平均油耗 (MPG)", "Consumo (MPG)")) {
                    TextField("30", value: $mpg, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 70)
                }
                if mpg > 0 {
                    LabeledContent(
                        loc("Est. Weekly Usage", "估算周耗油", "Uso sem. estimado"),
                        value: String(format: loc("%.1f gal", "%.1f 加仑", "%.1f gal"), weeklyMiles / mpg)
                    )
                }
            }

            // ── AI Server ─────────────────────────────────────────────
            Section(loc("AI Strategy Server", "AI 策略推理服务器", "Servidor IA")) {
                LabeledContent("Base URL") {
                    TextField("http://192.168.1.x:11434/v1", text: $llmBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent(loc("Model Name", "模型名称", "Nombre del modelo")) {
                    TextField("qwen2.5:14b", text: $llmModelName)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("API Key") {
                    SecureField(loc("Leave blank for local", "本地服务可留空", "Vacío para local"), text: $apiKeyField)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKeyField) { _, v in
                            KeychainHelper.setAPIKey(v.isEmpty ? nil : v)
                        }
                }

                HStack {
                    Button(loc("Test Connection", "测试连接", "Probar conexión")) {
                        llmTestResult = nil; llmTesting = true
                        Task {
                            let r = await LLMService.shared.testConnection()
                            switch r {
                            case .success(let msg): llmTestResult = "✓ " + msg
                            case .failure(let e):   llmTestResult = "✗ " + (e.errorDescription ?? loc("Failed", "失败", "Error"))
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
            Section(loc("About", "关于", "Acerca de")) {
                LabeledContent(loc("Version", "版本", "Versión"), value: "1.1.0")
                LabeledContent(loc("Data Source", "数据来源", "Fuente de datos"),
                               value: loc("Yahoo Finance (delayed quotes)", "Yahoo Finance（延迟行情）", "Yahoo Finance (cotiz. retrasadas)"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("Disclaimer", "免责声明", "Aviso legal"))
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
                Button(loc("Quit GasPulse", "退出 GasPulse", "Salir de GasPulse")) { NSApplication.shared.terminate(nil) }
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 800)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(loc("Done", "完成", "Listo")) { dismiss() }
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
                Text(loc("Notifications authorized", "通知权限已授权", "Notificaciones autorizadas"))
                    .font(.caption).foregroundStyle(.secondary)
            case .denied:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(loc("Notifications denied", "通知权限已拒绝", "Notificaciones denegadas"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(loc("Open System Settings", "前往系统设置", "Ajustes del sistema")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                }
                .font(.caption)
            default:
                Image(systemName: "bell.badge").foregroundStyle(.secondary)
                Text(loc("Notifications not authorized", "尚未授权通知", "Notificaciones sin autorizar"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(loc("Request Permission", "请求权限", "Solicitar permiso")) {
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

    @AppStorage("appLanguage") private var lang: String = "en"

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
                Toggle(loc("Upper", "上限", "Límite sup."), isOn: $upperEnabled)
                    .toggleStyle(.checkbox).disabled(!upperValid)
                    .onChange(of: upperEnabled) { _, _ in onCommit() }
                TextField(loc("Price", "价格", "Precio"), text: $upperText)
                    .textFieldStyle(.roundedBorder).frame(width: 80)
                    .onChange(of: upperText) { _, _ in
                        if let v = Double(upperText), v > 0 { onCommit() }
                        if upperEnabled && !upperValid { upperEnabled = false }
                    }
                Text(loc("alert above (USD)", "USD 以上提醒", "alertar por encima (USD)")).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Toggle(loc("Lower", "下限", "Límite inf."), isOn: $lowerEnabled)
                    .toggleStyle(.checkbox).disabled(!lowerValid)
                    .onChange(of: lowerEnabled) { _, _ in onCommit() }
                TextField(loc("Price", "价格", "Precio"), text: $lowerText)
                    .textFieldStyle(.roundedBorder).frame(width: 80)
                    .onChange(of: lowerText) { _, _ in
                        if let v = Double(lowerText), v > 0 { onCommit() }
                        if lowerEnabled && !lowerValid { lowerEnabled = false }
                    }
                Text(loc("alert below (USD)", "USD 以下提醒", "alertar por debajo (USD)")).font(.caption).foregroundStyle(.secondary)
            }

            if !bothValid {
                Text(loc("Lower must be less than upper", "下限价格必须小于上限价格", "El límite inf. debe ser menor"))
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}
