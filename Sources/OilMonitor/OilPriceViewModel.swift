import Foundation
import SwiftUI

@MainActor
final class OilPriceViewModel: ObservableObject {

    // MARK: - Published State

    @Published var brentPrice: OilPrice?
    @Published var wtiPrice: OilPrice?
    @Published var brentHistory: [PricePoint] = []
    @Published var wtiHistory: [PricePoint] = []
    @Published var isRefreshing = false
    @Published var isForceRefreshing = false
    @Published var dataStatus: DataStatus = .loading
    @Published var errorMessage: String?
    @Published var selectedSymbol: OilSymbol = .brent
    @Published var selectedRange: TimeRange = .oneDay
    @Published var lastRefreshedAt: Date?

    // MARK: - Settings

    @AppStorage("refreshIntervalMinutes") var refreshIntervalMinutes: Int = 30
    @AppStorage("showPriceInMenuBar") var showPriceInMenuBar: Bool = true

    // MARK: - Private

    private let service = YahooFinanceService()
    private let database = DatabaseService()
    private var normalRefreshTask: Task<Void, Never>?
    private var forceRefreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var lastNormalRefreshAt: Date?
    private let normalCooldown: TimeInterval = 10

    // MARK: - Init

    init() {
        Task {
            await loadFromCache()
            await performFetch()
        }
        scheduleTimer()
    }

    // MARK: - Cache

    private func loadFromCache() async {
        let b = await database.loadLatestPrice(for: OilSymbol.brent.rawValue)
        let w = await database.loadLatestPrice(for: OilSymbol.wti.rawValue)
        brentPrice = b
        wtiPrice = w
        dataStatus = (b != nil || w != nil) ? .cached : .noData
        await refreshHistoryFromCache()
    }

    private func refreshHistoryFromCache() async {
        let bh = await database.loadPriceHistory(for: OilSymbol.brent.rawValue, range: selectedRange)
        let wh = await database.loadPriceHistory(for: OilSymbol.wti.rawValue, range: selectedRange)
        brentHistory = bh
        wtiHistory = wh
    }

    // MARK: - Panel Opened

    func panelOpened() {
        if let t = normalRefreshTask, !t.isCancelled { return }
        normalRefreshTask = Task { await performFetch() }
    }

    // MARK: - Normal Refresh

    func refresh() {
        if isForceRefreshing { return }
        if let last = lastNormalRefreshAt, Date().timeIntervalSince(last) < normalCooldown { return }
        if let t = normalRefreshTask, !t.isCancelled { return }
        normalRefreshTask = Task { await performFetch() }
    }

    private func performFetch() async {
        guard !isForceRefreshing else { return }
        isRefreshing = true
        errorMessage = nil

        do {
            async let bFetch = service.fetchCurrentPrice(for: .brent)
            async let wFetch = service.fetchCurrentPrice(for: .wti)
            let (b, w) = try await (bFetch, wFetch)

            brentPrice = b
            wtiPrice = w
            await database.saveLatestPrice(b)
            await database.saveLatestPrice(w)

            await fetchAndSaveHistory()

            lastNormalRefreshAt = Date()
            lastRefreshedAt = Date()
            dataStatus = .normal
        } catch {
            errorMessage = error.localizedDescription
            if brentPrice != nil || wtiPrice != nil {
                dataStatus = .cached
            } else {
                dataStatus = .offline
            }
        }

        isRefreshing = false
    }

    // MARK: - Force Refresh

    func forceRefresh() {
        if let t = forceRefreshTask, !t.isCancelled { return }
        normalRefreshTask?.cancel()
        normalRefreshTask = nil

        forceRefreshTask = Task { await performForceRefresh() }
    }

    private func performForceRefresh() async {
        isRefreshing = true
        isForceRefreshing = true
        errorMessage = nil

        do {
            async let bFetch = service.fetchCurrentPrice(for: .brent)
            async let wFetch = service.fetchCurrentPrice(for: .wti)
            let (b, w) = try await (bFetch, wFetch)

            brentPrice = b
            wtiPrice = w
            await database.saveLatestPrice(b)
            await database.saveLatestPrice(w)

            await fetchAndSaveHistory()

            lastNormalRefreshAt = Date()
            lastRefreshedAt = Date()
            dataStatus = .normal
        } catch {
            errorMessage = error.localizedDescription
            if brentPrice != nil || wtiPrice != nil {
                dataStatus = .cached
            } else {
                dataStatus = .offline
            }
        }

        isRefreshing = false
        isForceRefreshing = false
        forceRefreshTask = nil
    }

    // MARK: - History

    private func fetchAndSaveHistory() async {
        do {
            async let bh = service.fetchHistory(for: .brent, range: selectedRange)
            async let wh = service.fetchHistory(for: .wti, range: selectedRange)
            let (b, w) = try await (bh, wh)
            brentHistory = b
            wtiHistory = w
            await database.savePriceHistory(b)
            await database.savePriceHistory(w)
        } catch {
            await refreshHistoryFromCache()
        }
    }

    func changeRange(_ range: TimeRange) {
        selectedRange = range
        Task {
            await refreshHistoryFromCache()
            await fetchAndSaveHistory()
        }
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(refreshIntervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.normalRefreshTask = Task { await self.performFetch() } }
        }
    }

    func updateTimerInterval() {
        scheduleTimer()
    }

    // MARK: - Computed

    var currentHistory: [PricePoint] {
        selectedSymbol == .brent ? brentHistory : wtiHistory
    }

    var menuBarText: String? {
        guard showPriceInMenuBar, let b = brentPrice, let w = wtiPrice else { return nil }
        return String(format: "B %.2f · W %.2f", b.price, w.price)
    }

    /// 上次成功刷新的真实时间（点击更新后会立即变化，作为操作反馈）。
    var lastUpdatedText: String {
        guard let t = lastRefreshedAt else { return "尚未刷新" }
        let diff = Date().timeIntervalSince(t)
        if diff < 60 { return "刚刚更新" }
        if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: t)
    }

    /// 行情数据本身的时间（休市时会停在最后一笔成交时间）。
    var marketTimeText: String? {
        let ref = brentPrice?.marketTime ?? wtiPrice?.marketTime
        guard let t = ref else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d HH:mm"
        return "行情 " + fmt.string(from: t)
    }
}
