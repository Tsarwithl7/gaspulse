import Foundation

struct StrategyEngine {

    // MARK: - Public Entry Point

    func computeSignals(
        brent: [PricePoint],
        wti:   [PricePoint],
        rbob:  [PricePoint],
        tankGallons: Double,
        weeklyMiles: Double,
        mpg: Double,
        now: Date = Date()
    ) -> LocalSignals {
        let bDaily = dailyCloses(brent)
        let wDaily = dailyCloses(wti)
        let gDailyRaw = dailyCloses(rbob)
        // RBOB 每月换月，换月日的跳价不是真实行情——用原油作参照修正后再计算信号
        let (gDaily, rollDays) = rollAdjusted(gDailyRaw, reference: wDaily)

        let brentMom  = momentumPct(bDaily, days: 20)
        let wtiMom    = momentumPct(wDaily, days: 20)
        let rbobMom   = momentumPct(gDaily, days: 20)
        let rbobShort = momentumPct(gDaily, days: 5)

        // Use WTI as the crude leg for crack spread (US gasoline tracks WTI)
        // 价差水平用真实报价；价差变化用换月修正后的序列，避免跳价污染
        let crackNow = crackSpread(crudePrice: wDaily.last?.price, rbobPrice: gDailyRaw.last?.price)
        let crackNowAdj = crackSpread(crudePrice: wDaily.last?.price, rbobPrice: gDaily.last?.price)
        let crack20  = crackSpread(
            crudePrice: priceNDaysAgo(wDaily, days: 20),
            rbobPrice:  priceNDaysAgo(gDaily, days: 20)
        )
        let crackChange: Double? = crackNowAdj.flatMap { n in crack20.map { n - $0 } }

        let (lagDays, lagCorr) = bestLeadLag(crudeDaily: wDaily, rbobDaily: gDaily)

        return LocalSignals(
            asOf: now,
            windowDays: 20,
            dataPointCount: min(bDaily.count, min(wDaily.count, gDaily.count)),
            brentMomentumPct: brentMom,
            wtiMomentumPct: wtiMom,
            rbobMomentumPct: rbobMom,
            rbobShortMomentumPct: rbobShort,
            crudeRbobLeadLagCorr: lagCorr,
            leadLagDays: lagDays,
            crackSpreadProxy: crackNow,
            crackSpreadChange: crackChange,
            rbobRollDaysAdjusted: rollDays,
            tankGallons: tankGallons,
            weeklyMiles: weeklyMiles,
            mpg: mpg
        )
    }

    // MARK: - Futures Roll Adjustment

    /// 检测并修正换月跳价：当目标品种单日收益与参照品种（原油）方向相反且
    /// 差值超过阈值时，判定为换月日。用参照品种当日收益重建该日价格，
    /// 其后价格整体缩放，保证收益率序列连续。返回修正后序列和换月天数。
    func rollAdjusted(
        _ series: [(day: Date, price: Double)],
        reference: [(day: Date, price: Double)],
        divergenceThreshold: Double = 0.04
    ) -> (series: [(day: Date, price: Double)], rollDays: Int) {
        guard series.count >= 2 else { return (series, 0) }
        let refReturns = Dictionary(uniqueKeysWithValues: dailyReturns(reference))

        var out = series
        var factor = 1.0
        var rollDays = 0
        for i in 1..<series.count {
            let prevRaw = series[i-1].price
            let curRaw  = series[i].price
            if prevRaw > 0 {
                let r = curRaw / prevRaw - 1
                var refR: Double?
                for offset in [0.0, -86400, 86400] {
                    if let v = refReturns[series[i].day.addingTimeInterval(offset)] {
                        refR = v
                        break
                    }
                }
                if let c = refR, r * c < 0, abs(r - c) > divergenceThreshold {
                    // 换月日：让该日收益等于原油收益（最优估计），跳价归零
                    factor = prevRaw * factor * (1 + c) / curRaw
                    rollDays += 1
                }
            }
            out[i].price = curRaw * factor
        }
        return (out, rollDays)
    }

    // MARK: - Daily Closes (dedup intraday → one close per calendar day)

    func dailyCloses(_ points: [PricePoint]) -> [(day: Date, price: Double)] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var buckets: [Date: (time: Date, price: Double)] = [:]
        for pt in points {
            let bucket = cal.startOfDay(for: pt.marketTime)
            if let existing = buckets[bucket] {
                if pt.marketTime > existing.time { buckets[bucket] = (pt.marketTime, pt.price) }
            } else {
                buckets[bucket] = (pt.marketTime, pt.price)
            }
        }
        return buckets
            .map { (day: $0.key, price: $0.value.price) }
            .sorted { $0.day < $1.day }
    }

    // MARK: - Momentum

    func momentumPct(_ daily: [(day: Date, price: Double)], days: Int) -> Double? {
        guard daily.count >= 2 else { return nil }
        let latest = daily.last!.price
        let cutoff = daily.last!.day.addingTimeInterval(-TimeInterval(days) * 86400)
        guard let ref = daily.first(where: { $0.day <= cutoff.addingTimeInterval(86400) }) else {
            return nil
        }
        guard ref.price > 0 else { return nil }
        return (latest / ref.price - 1) * 100
    }

    func priceNDaysAgo(_ daily: [(day: Date, price: Double)], days: Int) -> Double? {
        guard let latest = daily.last?.day else { return nil }
        let cutoff = latest.addingTimeInterval(-TimeInterval(days) * 86400)
        return daily.last(where: { $0.day <= cutoff.addingTimeInterval(86400) })?.price
    }

    // MARK: - Crack Spread

    func crackSpread(crudePrice: Double?, rbobPrice: Double?) -> Double? {
        guard let c = crudePrice, let r = rbobPrice, c > 0, r > 0 else { return nil }
        // RBOB in $/gal × 42 gal/barrel → $/barrel; subtract crude $/barrel
        return r * 42.0 - c
    }

    // MARK: - Lead-Lag Correlation (Pearson)

    func leadLagCorrelation(
        crudeDaily: [(day: Date, price: Double)],
        rbobDaily: [(day: Date, price: Double)],
        lag: Int,
        minPairs: Int = 8
    ) -> Double? {
        // Compute daily returns for each series
        let crudeReturns = dailyReturns(crudeDaily)
        let rbobReturns  = dailyReturns(rbobDaily)

        // Align by day: crude_return[day - lag] vs rbob_return[day]
        var pairs: [(x: Double, y: Double)] = []
        let crudeMap = Dictionary(uniqueKeysWithValues: crudeReturns)
        for (day, rbobR) in rbobReturns {
            let crudeDay = day.addingTimeInterval(-TimeInterval(lag) * 86400)
            // Search within ±1 day (weekend gaps)
            for offset in [0, -86400, 86400] as [TimeInterval] {
                let candidate = crudeDay.addingTimeInterval(offset)
                if let crudeR = crudeMap[candidate] {
                    pairs.append((crudeR, rbobR))
                    break
                }
            }
        }
        guard pairs.count >= minPairs else { return nil }
        return pearson(pairs)
    }

    func bestLeadLag(
        crudeDaily: [(day: Date, price: Double)],
        rbobDaily: [(day: Date, price: Double)]
    ) -> (lag: Int, corr: Double) {
        var best: (lag: Int, corr: Double) = (0, 0)
        for lag in 0...3 {
            if let r = leadLagCorrelation(crudeDaily: crudeDaily, rbobDaily: rbobDaily, lag: lag) {
                if abs(r) > abs(best.corr) { best = (lag, r) }
            }
        }
        return best
    }

    // MARK: - Helpers

    private func dailyReturns(_ daily: [(day: Date, price: Double)]) -> [(Date, Double)] {
        guard daily.count >= 2 else { return [] }
        var returns: [(Date, Double)] = []
        for i in 1..<daily.count {
            let prev = daily[i-1].price
            guard prev > 0 else { continue }
            returns.append((daily[i].day, daily[i].price / prev - 1))
        }
        return returns
    }

    private func pearson(_ pairs: [(x: Double, y: Double)]) -> Double {
        let n = Double(pairs.count)
        let mx = pairs.map(\.x).reduce(0, +) / n
        let my = pairs.map(\.y).reduce(0, +) / n
        let num  = pairs.map { ($0.x - mx) * ($0.y - my) }.reduce(0, +)
        let dx   = pairs.map { ($0.x - mx) * ($0.x - mx) }.reduce(0, +)
        let dy   = pairs.map { ($0.y - my) * ($0.y - my) }.reduce(0, +)
        let denom = (dx * dy).squareRoot()
        return denom > 0 ? num / denom : 0
    }
}
