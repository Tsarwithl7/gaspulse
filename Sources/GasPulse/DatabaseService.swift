import Foundation
import SQLite3

actor DatabaseService {
    nonisolated(unsafe) private var db: OpaquePointer?

    init() {
        openAndSetup()
    }

    // MARK: - Setup

    nonisolated private func openAndSetup() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GasPulse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("prices.db").path

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            print("[DB] Failed to open database at \(path)")
            return
        }
        exec("""
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS latest_prices (
                symbol TEXT PRIMARY KEY,
                price REAL NOT NULL,
                change REAL NOT NULL,
                change_percent REAL NOT NULL,
                currency TEXT NOT NULL,
                market_time INTEGER NOT NULL,
                source TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS price_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                symbol TEXT NOT NULL,
                price REAL NOT NULL,
                market_time INTEGER NOT NULL,
                source TEXT NOT NULL,
                UNIQUE(symbol, market_time)
            );
            CREATE INDEX IF NOT EXISTS idx_ph_sym_time ON price_history(symbol, market_time DESC);
            CREATE TABLE IF NOT EXISTS refresh_metadata (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                last_success_at INTEGER,
                last_attempt_at INTEGER,
                status TEXT NOT NULL DEFAULT 'never',
                error_message TEXT
            );
            INSERT OR IGNORE INTO refresh_metadata(id) VALUES(1);
        """)
    }

    nonisolated private func exec(_ sql: String) {
        sql.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .forEach { sqlite3_exec(db, $0, nil, nil, nil) }
    }

    // MARK: - Latest Prices

    func saveLatestPrice(_ price: OilPrice) {
        let sql = """
            INSERT OR REPLACE INTO latest_prices
            (symbol, price, change, change_percent, currency, market_time, source, updated_at)
            VALUES (?,?,?,?,?,?,?,?);
        """
        withStatement(sql) { stmt in
            sqlite3_bind_text(stmt, 1, price.symbol, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, price.price)
            sqlite3_bind_double(stmt, 3, price.change)
            sqlite3_bind_double(stmt, 4, price.changePercent)
            sqlite3_bind_text(stmt, 5, price.currency, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 6, Int64(price.marketTime.timeIntervalSince1970))
            sqlite3_bind_text(stmt, 7, price.source, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 8, Int64(Date().timeIntervalSince1970))
            sqlite3_step(stmt)
        }
    }

    func loadLatestPrice(for symbolRaw: String) -> OilPrice? {
        let sql = "SELECT symbol, price, change, change_percent, currency, market_time, source FROM latest_prices WHERE symbol=?;"
        var result: OilPrice?
        withStatement(sql) { stmt in
            sqlite3_bind_text(stmt, 1, symbolRaw, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let sym = String(cString: sqlite3_column_text(stmt, 0))
                let oilSymbol = OilSymbol(rawValue: sym) ?? .brent
                result = OilPrice(
                    id: UUID(),
                    symbol: sym,
                    name: oilSymbol.displayName,
                    price: sqlite3_column_double(stmt, 1),
                    currency: String(cString: sqlite3_column_text(stmt, 4)),
                    change: sqlite3_column_double(stmt, 2),
                    changePercent: sqlite3_column_double(stmt, 3),
                    marketTime: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 5))),
                    source: String(cString: sqlite3_column_text(stmt, 6))
                )
            }
        }
        return result
    }

    // MARK: - Price History

    func savePriceHistory(_ points: [PricePoint]) {
        guard !points.isEmpty else { return }
        exec("BEGIN TRANSACTION;")
        let sql = "INSERT OR IGNORE INTO price_history (symbol, price, market_time, source) VALUES (?,?,?,?);"
        withStatement(sql) { stmt in
            for pt in points {
                sqlite3_bind_text(stmt, 1, pt.symbol, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 2, pt.price)
                sqlite3_bind_int64(stmt, 3, Int64(pt.marketTime.timeIntervalSince1970))
                sqlite3_bind_text(stmt, 4, "Yahoo Finance", -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
        }
        exec("COMMIT;")
    }

    func loadPriceHistory(for symbolRaw: String, range: TimeRange) -> [PricePoint] {
        let cutoff = Int64(Date().addingTimeInterval(-range.historyLookback).timeIntervalSince1970)
        let sql = """
            SELECT symbol, price, market_time FROM price_history
            WHERE symbol=? AND market_time>=?
            ORDER BY market_time ASC LIMIT 500;
        """
        var points: [PricePoint] = []
        withStatement(sql) { stmt in
            sqlite3_bind_text(stmt, 1, symbolRaw, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 2, cutoff)
            while sqlite3_step(stmt) == SQLITE_ROW {
                points.append(PricePoint(
                    symbol: String(cString: sqlite3_column_text(stmt, 0)),
                    price: sqlite3_column_double(stmt, 1),
                    marketTime: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 2)))
                ))
            }
        }
        return points
    }

    // MARK: - Maintenance

    func pruneOldHistory() {
        let cutoff = Int64(Date().addingTimeInterval(-90 * 86400).timeIntervalSince1970)
        exec("DELETE FROM price_history WHERE market_time < \(cutoff);")
    }

    // MARK: - Helpers

    private func withStatement(_ sql: String, body: (OpaquePointer) -> Void) {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return }
        body(s)
    }

    deinit {
        sqlite3_close(db)
    }
}

// Constant needed for SQLite bind calls
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
