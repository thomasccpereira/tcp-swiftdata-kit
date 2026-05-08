import Foundation
import Testing
import SwiftUI
@testable import SwiftDataKit

@Suite("SQLiteDatabase tests", .serialized)
struct SQLiteDatabaseTests {
   private func openTempDB(_ url: URL) async throws -> SQLiteDatabase {
      try? FileManager.default.removeItem(at: url)
      try? await Task.sleep(nanoseconds: 1_000_000)
      
      let sqliteConfig = try #require(SQLiteConfiguration(path: url.path))
      let db = try SQLiteDatabase(config: sqliteConfig)
      try await db.exec("""
      CREATE TABLE IF NOT EXISTS item (
         id TEXT PRIMARY KEY,
         title TEXT NOT NULL,
         tags TEXT NOT NULL,
         note TEXT,
         image_data BLOB,
         rating REAL
      );
      """)
      return db
   }
   
   @Test func testExecInsertAndQuery() async throws {
      let url = TestPaths.temporaryFile("sqlite-insert-query")
      let db = try await openTempDB(url)
      let id = UUID().uuidString
      
      let imageData = UIImage(systemName: "xmark.bin")!.pngData()!
      let changed = try await db.exec("INSERT INTO item(id, title, tags, note, image_data, rating) VALUES(?,?,?,?,?,?)",
                                      [.text(id), .text("Alpha"), .text("x,y"), .text("hi"), .blob(imageData), .real(4.5)])
      #expect(changed == 1)
      
      let rows = try await db.query("SELECT id, title, tags, note, image_data, rating FROM item WHERE id = ?", [.text(id)])
      #expect(rows.count == 1)
      
      let singleRow = rows[0]
      try #expect(singleRow.string("title") == "Alpha")
      try #expect(singleRow.string("tags") == "x,y")
      try #expect(singleRow.string("note") == "hi")
      try #expect(singleRow.data("image_data") == imageData)
      try #expect(singleRow.double("rating") == 4.5)
   }
   
   @Test func testStreamingForEachUTF8Decoding() async throws {
      let url = TestPaths.temporaryFile("sqlite-streaming-utf")
      let db = try await openTempDB(url)
      try await db.exec("DELETE FROM item")
      for (index, title) in ["Árvore","Ωmega","Plain"].enumerated() {
         try await db.exec("INSERT INTO item(id, title, tags) VALUES(?,?,?)",
                           [.text(UUID().uuidString), .text(title), .text("t\(index)")])
      }
      
      let seen: [String] = try await db.mapRowsBuffered("SELECT title FROM item ORDER BY title") { row in
         if case let .text(title)? = row["title"] { return title }
         return nil
      }
      
      #expect(seen.sorted() == ["Plain","Árvore","Ωmega"].sorted())
   }
   
   @Test func testTransactions() async throws {
      let url = TestPaths.temporaryFile("sqlite-transactions")
      let db = try await openTempDB(url)
      try await db.exec("DELETE FROM item")
      
      _ = try await db.withTransaction {
         try await db.exec("INSERT INTO item(id, title, tags) VALUES(?,?,?)",
                           [.text(UUID().uuidString), .text("Keep"), .text("k")])
      }
      
      var count = try await db.query("SELECT COUNT(*) AS c FROM item").first?.int64("c")
      #expect(count == 1)
      
      do {
         try await db.withTransaction {
            try await db.exec("INSERT INTO item(id, title, tags) VALUES(?,?,?)",
                              [.text(UUID().uuidString), .text("Drop"), .text("d")])
            
            struct Boom: Error { }
            throw Boom()
         }
         
         #expect(Bool(false), "Should have thrown")
         
      } catch { /* expected */ }
      
      count = try await db.query("SELECT COUNT(*) AS c FROM item").first?.int64("c")
      #expect(count == 1)
   }
   
   @Test func testCloseAndReopen() async throws {
      let url = TestPaths.temporaryFile("sqlite-close-test")
      let sqliteConfig1 = try #require(SQLiteConfiguration(path: url.path))
      let db = try SQLiteDatabase(config: sqliteConfig1)
      await db.close()
      
      let sqliteConfig2 = try #require(SQLiteConfiguration(path: url.path))
      let db2 = try SQLiteDatabase(config: sqliteConfig2)
      await db2.close()
   }
}
