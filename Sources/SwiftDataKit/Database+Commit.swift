import SwiftData
import Foundation

public extension Database {
   func save() async throws {
      do {
         let context = modelExecutor.modelContext
         try context.save()
         
      } catch {
         throw DatabaseError.databaseOperationFails(
            action: .save,
            objectType: error.localizedDescription
         )
      }
   }
}
