import Foundation

struct YahooFinanceService {
    private let baseURL = "https://query2.finance.yahoo.com/v8/finance/chart/"

    // MARK: - Current Price

    func fetchCurrentPrice(for symbol: OilSymbol) async throws -> OilPrice {
        let encoded = symbol.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol.rawValue
        let urlStr = "\(baseURL)\(encoded)?interval=1d&range=2d&events=div%2Csplit"
        guard let url = URL(string: urlStr) else { throw FetchError.badURL }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FetchError.httpError
        }
        return try parseCurrentPrice(from: data, symbol: symbol)
    }

    // MARK: - History

    func fetchHistory(for symbol: OilSymbol, range: TimeRange) async throws -> [PricePoint] {
        let encoded = symbol.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol.rawValue
        let urlStr = "\(baseURL)\(encoded)?interval=\(range.yahooInterval)&range=\(range.yahooRange)"
        guard let url = URL(string: urlStr) else { throw FetchError.badURL }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FetchError.httpError
        }
        return try parseHistory(from: data, symbol: symbol)
    }

    // MARK: - Parsing

    private func parseCurrentPrice(from data: Data, symbol: OilSymbol) throws -> OilPrice {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chart = json["chart"] as? [String: Any],
            let results = chart["result"] as? [[String: Any]],
            let first = results.first,
            let meta = first["meta"] as? [String: Any]
        else { throw FetchError.parse }

        guard let price = meta["regularMarketPrice"] as? Double else { throw FetchError.parse }

        let prevClose = meta["previousClose"] as? Double
                     ?? meta["chartPreviousClose"] as? Double
                     ?? price
        let currency = meta["currency"] as? String ?? "USD"
        let marketTimeRaw = meta["regularMarketTime"] as? Int ?? Int(Date().timeIntervalSince1970)
        let marketTime = Date(timeIntervalSince1970: TimeInterval(marketTimeRaw))

        let change = price - prevClose
        let changePercent = prevClose > 0 ? (change / prevClose) * 100 : 0

        return OilPrice(
            id: UUID(),
            symbol: symbol.rawValue,
            name: symbol.displayName,
            price: price,
            currency: currency,
            change: change,
            changePercent: changePercent,
            marketTime: marketTime,
            source: "Yahoo Finance"
        )
    }

    private func parseHistory(from data: Data, symbol: OilSymbol) throws -> [PricePoint] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chart = json["chart"] as? [String: Any],
            let results = chart["result"] as? [[String: Any]],
            let first = results.first,
            let timestamps = first["timestamp"] as? [Int],
            let indicators = first["indicators"] as? [String: Any],
            let quotes = (indicators["quote"] as? [[String: Any]])?.first,
            let closes = quotes["close"] as? [Any]
        else { return [] }

        var points: [PricePoint] = []
        for (i, ts) in timestamps.enumerated() {
            guard i < closes.count else { break }
            let closeVal: Double?
            if let d = closes[i] as? Double {
                closeVal = d
            } else {
                closeVal = nil
            }
            guard let c = closeVal, c > 0 else { continue }
            points.append(PricePoint(
                symbol: symbol.rawValue,
                price: c,
                marketTime: Date(timeIntervalSince1970: TimeInterval(ts))
            ))
        }
        return points
    }

    // MARK: - Errors

    enum FetchError: LocalizedError {
        case badURL, httpError, parse

        var errorDescription: String? {
            switch self {
            case .badURL: return "URL 构建失败"
            case .httpError: return "服务器响应错误"
            case .parse: return "数据解析失败"
            }
        }
    }
}
