import Foundation
import SQLite3

// A strict-concurrency-safe SQLite wrapper.
/// - Isolates the raw SQLite connection inside an `actor`.
/// - Exposes async/await APIs for exec/query/transactions.
/// - Keeps all `OpaquePointer` usage internal to the actor.
public actor SQLiteDatabase {
   private var db: OpaquePointer?
   public let config: SQLiteConfiguration
   
   // IMPORTANT: no calls to actor‑isolated methods here.
   public init(config: SQLiteConfiguration) throws {
      self.config = config
      self.db = nil
      
      // Open connection
      var handle: OpaquePointer?
      var flags: Int32 = config.readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE
      if !config.readOnly, config.createIfMissing { flags |= SQLITE_OPEN_CREATE }
      flags |= SQLITE_OPEN_FULLMUTEX
      
      let result = sqlite3_open_v2(config.path, &handle, flags, nil)
      guard result == SQLITE_OK, let handle else {
         throw SQLiteError.openFailed(path: config.path, code: result, message: Self.lastMessage(from: handle))
      }
      self.db = handle
      
      // Configure connection (raw C helpers; no actor methods)
      _ = sqlite3_busy_timeout(handle, config.busyTimeoutMillis)
      try Self.exec(handle: handle, sql: "PRAGMA foreign_keys=\(config.foreignKeys ? 1 : 0);")
      // journal_mode returns a row; it's fine to run via exec (we ignore rows)
      try Self.exec(handle: handle, sql: "PRAGMA journal_mode=\(config.journalMode.rawValue);")
   }
   
   // MARK: - Public API
   public func close() {
      guard let handle = db else { return }
      db = nil
      _ = sqlite3_close(handle)
   }
   
   @discardableResult
   public func exec(_ sql: String, _ params: [SQLiteValue] = []) throws -> Int {
      try prepare(sql) { statement in
         try bind(params, to: statement, sql: sql)
         
         let result = sqlite3_step(statement)
         guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw stepError(sql: sql, result: result)
         }
         
         return Int(sqlite3_changes(db))
      }
   }
   
   public func query(_ sql: String, _ params: [SQLiteValue] = []) throws -> [SQLiteRow] {
      try prepare(sql) { statement in
         try bind(params, to: statement, sql: sql)
         return try collectRows(statement: statement)
      }
   }
   
   package func forEachRow(_ sql: String,
                           _ params: [SQLiteValue] = [],
                           handler: @Sendable (SQLiteRow) throws -> Void) throws {
      try prepare(sql) { statement in
         try bind(params, to: statement, sql: sql)
         let columnCount = Int(sqlite3_column_count(statement))
         
         let names: [String] = (0 ..< columnCount).map {
            let column = sqlite3_column_name(statement, Int32($0))
            return column.flatMap { String(cString: $0) } ?? "col\($0)"
         }
         
         while true {
            let result = sqlite3_step(statement)
            switch result {
            case SQLITE_ROW:
               let values = try readValues(statement: statement, columnCount: columnCount)
               try handler(SQLiteRow(columns: names, values: values))
               
            case SQLITE_DONE:
               return
               
            default:
               throw stepError(sql: sql, result: result)
            }
         }
      }
   }
   
   // Async *streaming*: steps and awaits your handler per row while the statement is open.
   // (Holds the stmt across awaits; OK if you want true streaming.)
   package func forEachRowAsync(streaming sql: String,
                                _ params: [SQLiteValue] = [],
                                handler: @Sendable (SQLiteRow) async throws -> Void) async throws {
      guard let db else {
         throw SQLiteError.openFailed(path: config.path, code: SQLITE_MISUSE, message: "Database not open")
      }
      
      var statement: OpaquePointer?
      let results = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
      guard results == SQLITE_OK, let statement else {
         throw SQLiteError.prepareFailed(sql: sql, code: results, message: Self.lastMessage(from: db))
      }
      defer { _ = sqlite3_finalize(statement) }
      
      try bind(params, to: statement, sql: sql)
      
      let columnCount = Int(sqlite3_column_count(statement))
      var names: [String] = []
      names.reserveCapacity(columnCount)
      for i in 0 ..< columnCount {
         let column = sqlite3_column_name(statement, Int32(i))
         names.append(column.flatMap { String(cString: $0) } ?? "col\(i)")
      }
      
      var n = 0
      while true {
         let step = sqlite3_step(statement)
         switch step {
         case SQLITE_ROW:
            let values = try readValues(statement: statement, columnCount: columnCount)
            try await handler(SQLiteRow(columns: names, values: values))
            n += 1
            if n % 64 == 0 { try Task.checkCancellation() }
            
         case SQLITE_DONE:
            return
            
         default:
            throw stepError(sql: sql, result: step)
         }
      }
   }
   
   // Async *buffered*: collects all rows first (stmt finalized), then awaits handler per row.
   // (No stmt across awaits; no reentrancy during stepping.)
   package func forEachRowAsync(buffered sql: String,
                                _ params: [SQLiteValue] = [],
                                handler: @Sendable (SQLiteRow) async throws -> Void) async throws {
      // Collect rows synchronously while statement is open
      let rows: [SQLiteRow] = try prepare(sql) { statement in
         try bind(params, to: statement, sql: sql)
         
         let columnCount = Int(sqlite3_column_count(statement))
         var names: [String] = []
         names.reserveCapacity(columnCount)
         for i in 0 ..< columnCount {
            let column = sqlite3_column_name(statement, Int32(i))
            names.append(column.flatMap { String(cString: $0) } ?? "col\(i)")
         }
         
         var rows: [SQLiteRow] = []
         while true {
            let step = sqlite3_step(statement)
            switch step {
            case SQLITE_ROW:
               let values = try readValues(statement: statement, columnCount: columnCount)
               rows.append(SQLiteRow(columns: names, values: values))
               if rows.count % 128 == 0 { try Task.checkCancellation() }
               
            case SQLITE_DONE:
               return rows
               
            default:
               throw stepError(sql: sql, result: step)
            }
         }
      }
      
      // Statement is finalized here; now it’s safe to await user handler per row
      for row in rows {
         try await handler(row)
      }
   }
   
   package func mapRowsBuffered<R: Sendable>(_ sql: String,
                                             _ params: [SQLiteValue] = [],
                                             transform: @Sendable (SQLiteRow) -> R?) async throws -> [R] {
      // 1) Collect rows synchronously while the statement is open.
      let rows: [SQLiteRow] = try prepare(sql) { statement in
         try bind(params, to: statement, sql: sql)
         
         let columnCount = Int(sqlite3_column_count(statement))
         var names: [String] = []
         names.reserveCapacity(columnCount)
         for i in 0 ..< columnCount {
            let column = sqlite3_column_name(statement, Int32(i))
            names.append(column.flatMap { String(cString: $0) } ?? "col\(i)")
         }
         
         var rows: [SQLiteRow] = []
         while true {
            let results = sqlite3_step(statement)
            switch results {
            case SQLITE_ROW:
               let values = try readValues(statement: statement, columnCount: columnCount)
               rows.append(SQLiteRow(columns: names, values: values))
               if rows.count % 128 == 0 { try Task.checkCancellation() }
               
            case SQLITE_DONE:
               return rows
               
            default:
               throw stepError(sql: sql, result: results)
            }
         }
      }
      
      // 2) Statement is finalized now. Map without mutating a captured var.
      return rows.compactMap(transform)
   }
   
   private func beginImmediate() throws { try exec("BEGIN IMMEDIATE;") }
   private func commit() throws { try exec("COMMIT;") }
   private func rollback() throws { try exec("ROLLBACK;") }
   
   // 1) Async body, returns a value (result crosses the actor boundary) ➜ R: Sendable
   public func withTransaction<R: Sendable>(_ body: @Sendable () async throws -> R) async throws -> R {
      try beginImmediate()
      
      do {
         let result = try await body()
         try commit()
         return result
         
      } catch {
         try rollback()
         throw error
      }
   }
   
   // 2) *Optional*: Async version if you want to `await` inside the transaction body
   public func withTransaction<R: Sendable>(_ body: @Sendable (isolated SQLiteDatabase) async throws -> R) async throws -> R {
      try beginImmediate()
      
      do {
         let result = try await body(self)
         try commit()
         return result
         
      } catch {
         try rollback()
         throw error
      }
   }
   
   // 2) Synchronous body, returns a value — no suspension → no actor reentrancy
   @discardableResult
   public func withTransactionSync<R: Sendable>(_ body: @Sendable (isolated SQLiteDatabase) throws -> R) throws -> R {
      try beginImmediate()
      
      do {
         let result = try body(self)
         try commit()
         return result
         
      } catch {
         try rollback()
         throw error
      }
   }
   
   // 3) Synchronous body, Void return
   public func withTransactionVoid(_ body: @Sendable (isolated SQLiteDatabase) throws -> Void) throws {
      try beginImmediate()
      
      do {
         try body(self)
         try commit()
         
      } catch {
         try rollback()
         throw error
      }
   }
   
   // MARK: - Actor‑isolated helpers
   private func prepare<T>(_ sql: String, block: (OpaquePointer?) throws -> T) throws -> T {
      guard let db else {
         throw SQLiteError.openFailed(path: config.path, code: SQLITE_MISUSE, message: "Database not open")
      }
      
      var statement: OpaquePointer?
      let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
      
      guard result == SQLITE_OK, let statement else {
         throw SQLiteError.prepareFailed(sql: sql, code: result, message: Self.lastMessage(from: db))
      }
      
      defer {
         let fin = sqlite3_finalize(statement)
         if fin != SQLITE_OK { /* optionally log */ }
      }
      
      return try block(statement)
   }
   
   private func bind(_ params: [SQLiteValue], to statement: OpaquePointer?, sql: String) throws {
      for (i, value) in params.enumerated() {
         let index = Int32(i + 1)
         let result: Int32
         
         switch value {
         case .null: result = sqlite3_bind_null(statement, index)
         case let .integer(integerValue): result = sqlite3_bind_int64(statement, index, integerValue)
         case let .real(doubleValue): result = sqlite3_bind_double(statement, index, doubleValue)
         case let .text(stringValue): result = stringValue.withCString { sqlite3_bind_text(statement, index, $0, -1, SQLITE_TRANSIENT) }
         case let .blob(data):
            result = data.withUnsafeBytes { buf in
               sqlite3_bind_blob(statement, index, buf.baseAddress, Int32(buf.count), SQLITE_TRANSIENT)
            }
         }
         
         guard result == SQLITE_OK else {
            throw SQLiteError.bindFailed(index: index, code: result, message: Self.lastMessage(from: db))
         }
      }
   }
   
   private func collectRows(statement: OpaquePointer?) throws -> [SQLiteRow] {
      let columnCount = Int(sqlite3_column_count(statement))
      let names: [String] = (0 ..< columnCount).map {
         let column = sqlite3_column_name(statement, Int32($0))
         return column.flatMap { String(cString: $0) } ?? "col\($0)"
      }
      
      var rows: [SQLiteRow] = []
      while true {
         let result = sqlite3_step(statement)
         switch result {
         case SQLITE_ROW:
            let values = try readValues(statement: statement, columnCount: columnCount)
            let row = SQLiteRow(columns: names,
                                values: values)
            rows.append(row)
            
         case SQLITE_DONE:
            return rows
            
         default:
            throw stepError(sql: "<query>", result: result)
         }
      }
   }
   
   private func readValues(statement: OpaquePointer?,
                           columnCount: Int) throws -> [SQLiteValue] {
      var values: [SQLiteValue] = []
      values.reserveCapacity(columnCount)
      
      for i in 0 ..< columnCount {
         let column = Int32(i)
         
         switch sqlite3_column_type(statement, column) {
         case SQLITE_NULL:
            values.append(.null)
            
         case SQLITE_INTEGER:
            values.append(.integer(sqlite3_column_int64(statement, column)))
            
         case SQLITE_FLOAT:
            values.append(.real(sqlite3_column_double(statement, column)))
            
         case SQLITE_TEXT:
            if let u8 = sqlite3_column_text(statement, column) {
               let len = Int(sqlite3_column_bytes(statement, column))
               let buffer = UnsafeBufferPointer(start: u8, count: len)
               let str = String(decoding: buffer, as: UTF8.self)
               values.append(.text(str))
               
            } else {
               values.append(.text(""))
            }
            
         case SQLITE_BLOB:
            if let bytes = sqlite3_column_blob(statement, column) {
               let len = Int(sqlite3_column_bytes(statement, column))
               values.append(.blob(Data(bytes: bytes, count: len)))
               
            } else {
               values.append(.blob(Data()))
            }
            
         default:
            values.append(.null)
         }
      }
      
      return values
   }
   
   private func stepError(sql: String,
                          result: Int32) -> SQLiteError {
      SQLiteError.stepFailed(sql: sql,
                             code: result,
                             message: Self.lastMessage(from: db))
   }
   
   // MARK: - Nonisolated raw helpers used during init
   private nonisolated static func exec(handle: OpaquePointer, sql: String) throws {
      var stmt: OpaquePointer?
      let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
      guard rc == SQLITE_OK, let stmt else {
         throw SQLiteError.prepareFailed(sql: sql, code: rc, message: Self.lastMessage(from: handle))
      }
      defer { _ = sqlite3_finalize(stmt) }
      let step = sqlite3_step(stmt)
      guard step == SQLITE_DONE || step == SQLITE_ROW else {
         throw SQLiteError.stepFailed(sql: sql, code: step, message: Self.lastMessage(from: handle))
      }
   }
   
   private nonisolated static func lastMessage(from handle: OpaquePointer?) -> String {
      guard let handle, let c = sqlite3_errmsg(handle) else { return "Unknown error" }
      return String(cString: c)
   }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
