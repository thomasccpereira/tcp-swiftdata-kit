import Foundation
import Testing
import SwiftUI
@testable import SwiftDataKit

@Suite("SQLiteDatabase sync and async - rows and transactions - tests", .serialized)
@MainActor
struct SQLiteWrapperSyncAndAsyncTests {
   @Test func testSyncForEachRow() async throws {
      let db = try makeDB(name: "Iter Sync Dummy")
      // Touch SwiftData to ensure the file exists
      _ = try await db.insert(model: DummyItemDTO(title: "touch"))
      
      let sql = try await db.openSQLite()
      try await bootstrapSchema(sql)
      
      let names = Box<[String]>([])
      try await sql.forEachRow("SELECT name FROM t ORDER BY name") { row in
         if case let .text(name)? = row["name"] {
            names.value.append(name) // safe via Box
         }
      }
      #expect(names.value == ["Alpha", "Beta", "Gamma"])
   }
   
   @Test func testAsyncStreamingForEachRow() async throws {
      let db = try makeDB(name: "Iter Streaming Dummy")
      _ = try await db.insert(model: DummyItemDTO(title: "touch"))
      
      let sql = try await db.openSQLite()
      try await bootstrapSchema(sql)
      
      let acc = Acc<String>()
      try await sql.forEachRowAsync(streaming: "SELECT name FROM t ORDER BY name") { row in
         if case let .text(name)? = row["name"] { await acc.add(name) }
      }
      let seen = await acc.snap()
      #expect(seen == ["Alpha", "Beta", "Gamma"])
   }
   
   @Test func testAsyncBufferedForEachRow() async throws {
      let db = try makeDB(name: "Iter Buffered Dummy")
      _ = _ = try await db.insert(model: DummyItemDTO(title: "touch"))
      
      let sql = try await db.openSQLite()
      try await bootstrapSchema(sql)
      
      let acc = Acc<String>()
      try await sql.forEachRowAsync(buffered: "SELECT name FROM t ORDER BY name") { row in
         if case let .text(name)? = row["name"] { await acc.add(name) }
      }
      let seen = await acc.snap()
      #expect(seen == ["Alpha", "Beta", "Gamma"])
   }
   
   @Test func testSyncTransactionCommitAndRollback() async throws {
      let database = try makeDB(name: "TxnSync-Dummy")
      
      let sql = try await database.openSQLite()
      
      // Schema
      try await sql.exec("""
          CREATE TABLE IF NOT EXISTS kv(
            k TEXT PRIMARY KEY,
            v TEXT NOT NULL
          );
      """)
      try await sql.exec("DELETE FROM kv")
      
      // --- Commit case
      let committed: Bool = try await sql.withTransaction { db in
         // NOTE: db is `isolated SQLiteDatabase` — call actor methods without `await`
         _ = try db.exec("INSERT INTO kv(k, v) VALUES(?,?)", [.text("a"), .text("1")])
         return true
      }
      #expect(committed == true)
      
      var rows = try await sql.query("SELECT v FROM kv WHERE k = 'a'")
      #expect(rows.first?.string("v") == "1")
      
      // --- Rollback case
      struct Boom: Error { }
      do {
         _ = try await sql.withTransaction { db in
            _ = try db.exec("INSERT INTO kv(k, v) VALUES(?,?)", [.text("b"), .text("2")])
            throw Boom()  // triggers rollback
         } as Bool
         #expect(Bool(false), "Expected rollback path to throw")
      } catch is Boom {
         // expected
      }
      
      rows = try await sql.query("SELECT v FROM kv WHERE k = 'b'")
      #expect(rows.isEmpty)
   }
   
   @Test func testVoidTransactionCommitAndRollback() async throws {
      let database = try makeDB(name: "TxnVoid-Dummy")
      
      let sql = try await database.openSQLite()
      
      // Schema
      try await sql.exec("""
          CREATE TABLE IF NOT EXISTS kv2(
            k TEXT PRIMARY KEY,
            v TEXT NOT NULL
          );
      """)
      try await sql.exec("DELETE FROM kv2")
      
      // --- Commit case
      try await sql.withTransaction { db in
         _ = try db.exec("INSERT INTO kv2(k, v) VALUES(?,?)", [.text("x"), .text("9")])
      }
      var rows = try await sql.query("SELECT v FROM kv2 WHERE k = 'x'")
      #expect(rows.first?.string("v") == "9")
      
      // --- Rollback case
      struct Boom: Error {}
      do {
         try await sql.withTransaction { db in
            _ = try db.exec("INSERT INTO kv2(k, v) VALUES(?,?)", [.text("y"), .text("10")])
            throw Boom()
         }
         #expect(Bool(false), "Expected rollback path to throw")
      } catch is Boom {
         // expected
      }
      
      rows = try await sql.query("SELECT v FROM kv2 WHERE k = 'y'")
      #expect(rows.isEmpty)
   }
   
   @Test func testAsyncTransactionAsyncBody() async throws {
      let database = try makeDB(name: "TxnAsync-Dummy")
      
      let sql = try await database.openSQLite()
      
      try await sql.exec("""
          CREATE TABLE IF NOT EXISTS tally(
            id INTEGER PRIMARY KEY,
            n  INTEGER NOT NULL
          );
      """)
      try await sql.exec("DELETE FROM tally")
      
      // Use the async-body variant to call `await` inside the transaction
      let value: Int = try await sql.withTransaction { db in
         _ = try db.exec("INSERT INTO tally(id, n) VALUES(?,?)", [.integer(1), .integer(40)])
         // Simulate an async hop you'd need in real life (e.g., await another actor)
         try await Task.sleep(nanoseconds: 50_000)
         _ = try db.exec("UPDATE tally SET n = n + 2 WHERE id = 1")
         // Read back inside the same transaction (no await needed on db)
         let rows = try db.query("SELECT n FROM tally WHERE id = 1")
         return Int(rows.first?.int64("n") ?? -1)
      }
      
      #expect(value == 42)
   }
}

// MARK: - Helpers
// Disk-backed DB using your initializer (no explicit file URL passed)
@MainActor
private func makeDB(name: String) throws -> Database {
   try Database(models: [DummyItemDAO.self, DummyDetailDAO.self],
                config: .init(inMemory: false, configurationName: name))
}

private func bootstrapSchema(_ sql: SQLiteDatabase) async throws {
   try await sql.exec("""
   CREATE TABLE IF NOT EXISTS t(
       id   INTEGER PRIMARY KEY,
       name TEXT NOT NULL
   );
   """)
   try await sql.exec("DELETE FROM t")
   for (id, name) in [(2,"Beta"), (3,"Gamma"), (1,"Alpha")] {
      _ = try await sql.exec("INSERT INTO t(id, name) VALUES(?,?)",
                             [.integer(Int64(id)), .text(name)])
   }
}

// Test-only Box to mutate inside a @Sendable sync closure (don’t ship this).
final class Box<T>: @unchecked Sendable {
   var value: T
   
   init(_ v: T) {
      value = v
   }
}

actor Acc<T: Sendable> {
   private var a: [T] = []
   
   func add(_ x: T) {
      a.append(x)
   }
   
   func snap() -> [T] {
      a
   }
}
