import Foundation
import Testing
import SQLite3
@testable import SwiftDataKit

@Suite("SQLiteDatabase errors tests", .serialized)
struct SQLiteErrorTests {
   @Test func testOpenFailed() throws {
      // A path that should not exist; readOnly + no createIfMissing
      let tempPath = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent(UUID().uuidString)
         .appendingPathExtension("sqlite")
      
      let optionalConfig = SQLiteConfiguration(path: tempPath.path(percentEncoded: false),
                                               readOnly: true,
                                               createIfMissing: false)
      let config = try #require(optionalConfig)
      
      do {
         _ = try SQLiteDatabase(config: config)
         #expect(Bool(false), "Expected open to fail for read-only non-existent path")
      } catch let SQLiteError.openFailed(path, code, message) {
         #expect(path == config.path)
         #expect(code != SQLITE_OK)
         #expect(!message.isEmpty)
      } catch {
         #expect(Bool(false), "Unexpected error: \(error)")
      }
   }
   
   @Test func testPrepareFailed() async throws {
      let optionalConfig = SQLiteConfiguration(path: ":memory:")
      let config = try #require(optionalConfig)
      let db = try SQLiteDatabase(config: config)
      
      do {
         _ = try await db.query("SELEC 1")
         #expect(Bool(false), "Expected prepare to fail")
         
      } catch let SQLiteError.prepareFailed(sql, code, message) {
         #expect(sql.contains("SELEC"))
         #expect(code != SQLITE_OK)
         #expect(!message.isEmpty)
         
      } catch {
         #expect(Bool(false), "Unexpected error: \(error)")
      }
   }
   
   @Test func testStepFailed() async throws {
      let optionalConfig = SQLiteConfiguration(path: ":memory:")
      let config = try #require(optionalConfig)
      let db = try SQLiteDatabase(config: config)
      
      // Create a table with a UNIQUE/PK constraint
      try await db.exec("""
          CREATE TABLE kv(
              k TEXT PRIMARY KEY,
              v TEXT NOT NULL
          );
      """)
      
      // First insert succeeds
      _ = try await db.exec("INSERT INTO kv(k, v) VALUES(?,?)", [.text("a"), .text("1")])
      
      // Second insert violates the primary key constraint — fails at step
      do {
         _ = try await db.exec("INSERT INTO kv(k, v) VALUES(?,?)", [.text("a"), .text("2")])
         #expect(Bool(false), "Expected UNIQUE constraint failure at step")
         
      } catch let SQLiteError.stepFailed(sql, code, message) {
         #expect(sql.contains("INSERT INTO kv"))
         #expect(code != SQLITE_OK)
         // Typical message contains "constraint" or "UNIQUE"
         #expect(message.lowercased().contains("constraint") || message.lowercased().contains("unique"))
         
      } catch {
         #expect(Bool(false), "Unexpected error: \(error)")
      }
   }
   
   @Test func testBindFailed() async throws {
      let optionalConfig = SQLiteConfiguration(path: ":memory:")
      let config = try #require(optionalConfig)
      let db = try SQLiteDatabase(config: config)
      
      do {
         // Statement has 0 params; binding 1 param yields SQLITE_RANGE in bind → bindFailed
         _ = try await db.exec("SELECT 1", [.integer(123)])
         #expect(Bool(false), "Expected bind to fail due to SQLITE_RANGE")
         
      } catch let SQLiteError.bindFailed(index, code, message) {
         #expect(index == 1) // 1-based index we attempted to bind
         #expect(code != SQLITE_OK)
         #expect(!message.isEmpty)
         
      } catch {
         #expect(Bool(false), "Unexpected error: \(error)")
      }
   }
   
   @Test func testFinalizeFailedDescription() {
      let err = SQLiteError.finalizeFailed(code: 9999)
      let desc = err.errorDescription ?? ""
      #expect(!desc.isEmpty)
   }
   
   @Test func testUnknownErrorDescription() {
      let err = SQLiteError.unknown(code: 123, message: "boom")
      let desc = err.errorDescription ?? ""
      #expect(!desc.isEmpty)
      #expect(desc.lowercased().contains("123") || desc.contains("123"))
   }
}
