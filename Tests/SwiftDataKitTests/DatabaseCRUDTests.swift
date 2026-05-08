import Foundation
import SwiftData
import Testing
import SwiftUI
@testable import SwiftDataKit

@Suite("Database CRUD tests", .serialized)
@MainActor
struct DatabaseCRUDTests {
   // Build the store in-memory using the wrapper (no direct ModelContext in tests)
   private func makeDatabase() throws -> Database {
      try Database(models: [DummyItemDAO.self, DummyDetailDAO.self],
                   config: .init(inMemory: true))
   }
   
   // Convenience sort/predicate used in multiple tests
   private let byTitleAsc: [SortDescriptor<DummyItemDAO>] = [
      SortDescriptor(\.title, order: .forward)
   ]
   
   @Test func testBatchUpsertAndFetchAndFirst() async throws {
      let db = try makeDatabase()
      
      // Seed three rows via batchUpsert (DTO → DAO).
      let seed: [DummyItemDTO] = [
         .init(title: "A", tags: ["x"], detail: .init(note: "a-note")),
         .init(title: "B", tags: ["y","z"], detail: nil),
         .init(title: "C", tags: ["w"], detail: .init(note: "c-note")),
      ]
      let result = try await db.batchUpsert(seed)
      #expect(result.inserted == 3)
      #expect(result.updated == 0)
      
      // Fetch all as domain models, sorted
      let all: [DummyItemModel] = try await db.fetch(
         matching: nil,
         sortBy: byTitleAsc
      )
      #expect(all.count == 3)
      #expect(all.first?.title == "A")
      #expect(all.first?.detail?.note == "a-note")
      #expect(all.last?.title == "C")
      
      // First matching “B”
      let onlyB = #Predicate<DummyItemDAO> { $0.title == "B" }
      let firstB: DummyItemModel? = try await db.first(matching: onlyB)
      #expect(firstB?.title == "B")
      #expect(firstB?.detail?.note == nil)
   }
   
   @Test func testUpdateFirstMutatesDAO() async throws {
      let db = try makeDatabase()
      
      // Seed one
      let dto = DummyItemDTO(title: "Original", tags: ["t"], detail: .init(note: "n"))
      _ = try await db.batchUpsert([dto])
      
      // Mutate the first matching row (by PK)
      let dtoID = dto.id
      let primaryKey = #Predicate<DummyItemDAO> { $0.id == dtoID }
      let updated = try await db.updateFirst(matching: primaryKey) { (dao: inout DummyItemDAO) in
         dao.title = "Updated"
         dao.tags = "\(dao.tags), new"
         dao.detail = dao.detail ?? DummyDetailDAO(note: "")
         dao.detail!.note = "changed"
      }
      #expect(updated)
      
      // Verify through domain fetch
      let fetched = try await db.first(matching: primaryKey)
      #expect(fetched?.title == "Updated")
      #expect(fetched?.tags.contains("new") == true)
      #expect(fetched?.detail?.note == "changed")
   }
   
   @Test func testUpdateAllBulkEditAndSaveOnce() async throws {
      let db = try makeDatabase()
      
      // Seed
      let seed: [DummyItemDTO] = [
         .init(title: "One"),
         .init(title: "Two"),
         .init(title: "Three"),
      ]
      _ = try await db.batchUpsert(seed)
      
      // Bulk append "*" to titles
      let edited = try await db.updateAll(matching: nil) { (dao: inout DummyItemDAO) in
         dao.title += "*"
      }
      #expect(edited == 3)
      
      // Confirm titles changed
      let all = try await db.fetch(matching: nil, sortBy: byTitleAsc)
      #expect(all.map(\.title).contains("One*") == true)
      #expect(all.map(\.title).contains("Three*") == true)
      #expect(all.map(\.title).contains("Two*") == true)
   }
   
   @Test func testCountWithPredicate() async throws {
      let db = try makeDatabase()
      
      // Seed
      let seed: [DummyItemDTO] = [
         .init(title: "Hit", tags: ["k"]),
         .init(title: "Miss", tags: []),
         .init(title: "Hit", tags: ["k","z"]),
      ]
      _ = try await db.batchUpsert(seed)
      
      // Count “Hit”
      let matching = #Predicate<DummyItemDAO> { $0.title == "Hit" }
      let hits = try await db.count(of: DummyItemDAO.self, matching: matching)
      #expect(hits == 2)
   }
   
   @Test func testUpsertUpdatesExisting() async throws {
      let db = try makeDatabase()
      
      // Insert
      var dto = DummyItemDTO(title: "Alpha", tags: ["a"], detail: nil)
      _ = try await db.batchUpsert([dto])
      
      // Change and upsert again (should update, not insert)
      dto.title = "Alpha*"
      dto.detail = .init(note: "present")
      let res = try await db.batchUpsert([dto])
      #expect(res.updated == 1)
      #expect(res.inserted == 0)
      
      // Verify
      let dtoID = dto.id
      let byPrimaryKey = #Predicate<DummyItemDAO> { $0.id == dtoID }
      let after = try await db.first(matching: byPrimaryKey)
      #expect(after?.title == "Alpha*")
      #expect(after?.detail?.note == "present")
   }
   
   @Test func testUpdateFirstReturnsFalseWhenMissing() async throws {
      let db = try makeDatabase()
      
      let id = UUID()
      let missing = #Predicate<DummyItemDAO> { $0.id == id }
      let changed = try await db.updateFirst(matching: missing) { (dao: inout DummyItemDAO) in
         dao.title = "won't happen"
      }
      #expect(changed == false)
   }
}
