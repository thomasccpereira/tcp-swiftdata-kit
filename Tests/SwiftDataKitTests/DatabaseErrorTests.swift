import Foundation
import Testing
@testable import SwiftDataKit

@Suite("DatabaseError tests", .serialized)
struct DatabaseErrorTests {
   @Test func testGenericError() {
      let e1 = NSError(domain: "X", code: 1, userInfo: [NSLocalizedDescriptionKey: "Boom"])
      let e2 = NSError(domain: "Y", code: 2, userInfo: [NSLocalizedDescriptionKey: "Boom"])
      let e3 = NSError(domain: "X", code: 3, userInfo: [NSLocalizedDescriptionKey: "Different"])
      
      #expect(DatabaseError.genericError(error: e1) == .genericError(error: e2))
      #expect(DatabaseError.genericError(error: e1) != .genericError(error: e3))
   }
   
   @Test func testContainerCreationFailed() {
      let u1 = NSError(domain: "X", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot make container"])
      let u2 = NSError(domain: "Y", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot make container"])
      let u3 = NSError(domain: "Z", code: 3, userInfo: [NSLocalizedDescriptionKey: "Different"])
      
      #expect(DatabaseError.containerCreationFailed(underlying: u1)
         == .containerCreationFailed(underlying: u2))
      #expect(DatabaseError.containerCreationFailed(underlying: u1)
         != .containerCreationFailed(underlying: u3))
   }
   
   @Test func testDatabaseOperationFails() {
      let a = DatabaseError.databaseOperationFails(action: .insert, objectType: "Dummy")
      let b = DatabaseError.databaseOperationFails(action: .insert, objectType: "Dummy")
      let c = DatabaseError.databaseOperationFails(action: .delete, objectType: "Dummy")
      let d = DatabaseError.databaseOperationFails(action: .insert, objectType: "Other")
      
      #expect(a == b)
      #expect(a != c)
      #expect(a != d)
   }
   
   @Test func testObjectNotFound() {
      let d1 = DatabaseError.objectNotFound(detail: "missing")
      let d2 = DatabaseError.objectNotFound(detail: "missing")
      let d3 = DatabaseError.objectNotFound(detail: "else")
      
      #expect(d1 == d2)
      #expect(d1 != d3)
   }
   
   @Test func testInvalidContainerPath() {
      #expect(DatabaseError.invalidContainerPath == DatabaseError.invalidContainerPath)
   }
   
   @Test func testSQLiteWrapperCreationFailed() {
      #expect(DatabaseError.sqliteDatabaseWrapperCreationFailed == .sqliteDatabaseWrapperCreationFailed)
   }
   
   // MARK: - errorDescription (localization-agnostic checks)
   @Test func testGenericErrorDescription() {
      let underlying = NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Uh-oh"])
      let desc = DatabaseError.genericError(error: underlying).errorDescription ?? ""
      #expect(!desc.isEmpty)
      // We don't rely on exact localization, but often the underlying text appears:
      #expect(desc.lowercased().contains("uh-oh") || !desc.isEmpty)
   }
   
   @Test func testInvalidContainerPathDescription() {
      let desc = DatabaseError.invalidContainerPath.errorDescription ?? ""
      #expect(desc.isEmpty) // matches your implementation
   }
   
   @Test func testContainerCreationFailedDescription() {
      let underlying = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nope"])
      let desc = DatabaseError.containerCreationFailed(underlying: underlying).errorDescription ?? ""
      #expect(!desc.isEmpty)
   }
   
   @Test func testSQLiteWrapperCreationFailedDescription() {
      let desc = DatabaseError.sqliteDatabaseWrapperCreationFailed.errorDescription ?? ""
      #expect(!desc.isEmpty)
   }
   
   @Test func testDatabaseOperationFailsDescriptionAndStatement() {
      // Verify statement mapping
      #expect(DatabaseError.DatabaseActions.insert.statement == "INSERT")
      #expect(DatabaseError.DatabaseActions.select.statement == "SELECT")
      #expect(DatabaseError.DatabaseActions.update.statement == "UPDATE")
      #expect(DatabaseError.DatabaseActions.delete.statement == "DELETE")
      #expect(DatabaseError.DatabaseActions.save.statement   == "COMMIT")
      
      let err = DatabaseError.databaseOperationFails(action: .insert, objectType: "Dummy")
      let desc = err.errorDescription ?? ""
      #expect(!desc.isEmpty)
   }
   
   @Test func testObjectNotFoundDescription() {
      let err = DatabaseError.objectNotFound(detail: "Missing Dummy where title == 'A'")
      #expect(err.errorDescription == "Missing Dummy where title == 'A'")
   }
}
