import Foundation
import Testing
import SwiftUI
@testable import SwiftDataKit

@Suite("SQLiteDatabase from Database tests", .serialized)
@MainActor
struct DatabaseSQLiteBridgeTests {
   @Test func testSwiftDataAndSQLiteShareSameFile() async throws {
      let configurationName = "BridgeTest"
      // Build a disk-backed DB with a predictable path
      let db = try Database(models: [DummyItemDAO.self, DummyDetailDAO.self],
                            config: .init(inMemory: false, configurationName: configurationName))
      
      // Confirm URL ends with .sqlite and the file exists (or is created after first write)
      let databaseURL = try await #require(db.databaseStoreURL?.path(percentEncoded: false))
      #expect(databaseURL.hasSuffix("BridgeTest.sqlite") == true)
      
      // Touch SwiftData to force file creation
      let object = DummyItemDTO(title: "Hello")
      _ = try await db.insert(model: object)
      
      // File should now exist
      let fileExists = FileManager.default.fileExists(atPath: databaseURL)
      #expect(fileExists == true)
      
      // Open with raw SQLite and read pragma
      let sql = try await db.openSQLite()
      try await sql.exec("PRAGMA foreign_keys=ON;")
      let rows = try await sql.query("PRAGMA user_version;")
      #expect(!rows.isEmpty)
   }
   
   @Test func testSwiftDataAndSQLiteInMemory() async throws {
      // Build a disk-backed DB with a predictable path
      let db = try Database(models: [DummyItemDAO.self, DummyDetailDAO.self],
                            config: .init(inMemory: true, configurationName: "test-in-memory-database"))
      
      // Touch SwiftData to force file creation
      let object = DummyItemDTO(title: "Hello")
      _ = try await db.insert(model: object)
      
      // Open with raw SQLite and read pragma
      let sql = try await db.openSQLite()
      try await sql.exec("PRAGMA foreign_keys=ON;")
      let rows = try await sql.query("PRAGMA user_version;")
      #expect(!rows.isEmpty)
   }
   
   @Test func testSwiftDataAndSQLiteInvalidPath() async throws {
      // Try to create a disk based database without a name
      #expect(throws: DatabaseError.invalidContainerPath) {
         let _ = try Database(models: [DummyItemDAO.self, DummyDetailDAO.self],
                              config: .init(inMemory: false, configurationName: ""))
      }
   }
   
   @Test func testSQLiteGetterOpens() async throws {
      let db = try makeDiskBackedDatabase()
      
      // Obtain the SQLiteDatabase actor via the getter
      let sqlite = try await db.openSQLite()
      
      // Run a trivial pragma and DDL using the SQLite actor
      try await sqlite.exec("PRAGMA foreign_keys=ON;")
      try await sqlite.exec("""
          CREATE TABLE IF NOT EXISTS t(
              id   TEXT PRIMARY KEY,
              name TEXT NOT NULL
          );
      """)
      
      // Insert & query roundtrip
      let id = UUID().uuidString
      _ = try await sqlite.exec("INSERT INTO t(id, name) VALUES(?,?)", [.text(id), .text("ok")])
      let rows = try await sqlite.query("SELECT name FROM t WHERE id = ?", [.text(id)])
      
      #expect(rows.count == 1)
      try #expect(rows[0].string("name") == "ok")
   }
   
   @Test func testSQLiteGetterMultipleHandles() async throws {
      let db = try makeDiskBackedDatabase()
      
      // First handle: create table + insert
      let sqlite1 = try await db.openSQLite()
      try await sqlite1.exec("""
          CREATE TABLE IF NOT EXISTS kv(
              k TEXT PRIMARY KEY,
              v TEXT NOT NULL
          );
      """)
      _ = try await sqlite1.exec("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)",
                                 [.text("greeting"), .text("hello")])
      
      // Second handle: read the value (should see the same file contents)
      let sqlite2 = try await db.openSQLite()
      let got = try await sqlite2.query("SELECT v FROM kv WHERE k = ?", [.text("greeting")])
      #expect(got.first?.string("v") == "hello")
   }
}

// MARK: - Helpers
@MainActor
// Builds a real (on‑disk) Database so `databaseStoreURL` is valid.
private func makeDiskBackedDatabase() throws -> Database {
   try Database(
      models: [DummyItemDAO.self, DummyDetailDAO.self],
      config: .init(inMemory: false, configurationName: "sqlitedatabase.from.database")
   )
}
