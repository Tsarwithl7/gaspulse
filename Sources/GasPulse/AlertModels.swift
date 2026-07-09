import Foundation

enum AlertDirection {
    case above, below
}

struct AlertFiring {
    let symbol: OilSymbol
    let direction: AlertDirection
    let price: Double
    let threshold: Double
    let marketTime: Date

    var notificationTitle: String {
        let dir = direction == .above
            ? loc("broke above upper limit", "突破上限")
            : loc("fell below lower limit",  "跌破下限")
        return "\(symbol.displayName) \(loc("price", "价格"))\(dir)"
    }

    var notificationBody: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        if loc("en", "zh") == "en" {
            return String(format: "Now $%.2f, threshold $%.2f (market %@)",
                          price, threshold, fmt.string(from: marketTime))
        } else {
            return String(format: "当前 $%.2f，阈值 $%.2f（行情 %@）",
                          price, threshold, fmt.string(from: marketTime))
        }
    }
}
