import Foundation

// MARK: - Enums

enum StrategyRecommendation: String, Codable {
    case fillNow = "fill_now"
    case wait    = "wait"
    case neutral = "neutral"

    var displayText: String {
        switch self {
        case .fillNow:  return loc("Fill Up Now",  "建议现在加油")
        case .wait:     return loc("Wait for Now", "建议再等等")
        case .neutral:  return loc("Unclear",      "暂不明朗")
        }
    }

    var color: String {
        switch self {
        case .fillNow:  return "green"
        case .wait:     return "orange"
        case .neutral:  return "secondary"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StrategyRecommendation(rawValue: raw) ?? .neutral
    }
}

enum StrategyConfidence: String, Codable {
    case low, medium, high

    var displayText: String {
        switch self {
        case .low:    return loc("Low",    "低")
        case .medium: return loc("Medium", "中")
        case .high:   return loc("High",   "高")
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StrategyConfidence(rawValue: raw) ?? .low
    }
}

enum TrendDirection: String, Codable {
    case rising, falling, stable

    var displayText: String {
        switch self {
        case .rising:  return loc("Rising",  "上涨")
        case .falling: return loc("Falling", "下跌")
        case .stable:  return loc("Stable",  "平稳")
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TrendDirection(rawValue: raw) ?? .stable
    }
}

// MARK: - Signals (computed locally, sent to LLM)

struct LocalSignals {
    let asOf: Date
    let windowDays: Int
    let dataPointCount: Int

    let brentMomentumPct: Double?
    let wtiMomentumPct: Double?
    let rbobMomentumPct: Double?
    let rbobShortMomentumPct: Double?

    let crudeRbobLeadLagCorr: Double?
    let leadLagDays: Int

    let crackSpreadProxy: Double?
    let crackSpreadChange: Double?

    let rbobRollDaysAdjusted: Int

    let tankGallons: Double
    let weeklyMiles: Double
    let mpg: Double

    var weeklyFuelGallons: Double { mpg > 0 ? weeklyMiles / mpg : 0 }
}

// MARK: - LLM Response (strict JSON schema)

struct LLMStrategyResponse: Codable {
    let recommendation: StrategyRecommendation
    let confidence: StrategyConfidence
    let trend: TrendDirection
    let outlook: String
    let reasoning: String
    let estimatedPriceChangePct: Double
}

// MARK: - Cached Plan

struct StrategyPlan: Codable, Equatable {
    let recommendation: StrategyRecommendation
    let confidence: StrategyConfidence
    let trend: TrendDirection
    let outlook: String
    let reasoning: String
    let estimatedPriceChangePct: Double
    let generatedAt: Date
    let modelName: String
}
