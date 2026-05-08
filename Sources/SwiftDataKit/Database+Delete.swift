import SwiftData
import Foundation
import CoreResources

public extension Database {
   // MARK: - Delete
   // Single delete
   func delete<T>(
      model: T
   ) throws where T: DatabaseUpsertable {
      let context = modelExecutor.modelContext
      
      if let dao = try firstDAO(matching: model.predicatePrimaryKey) {
         context.delete(dao)
         try context.save()
      }
   }
   // Delete all matching
   func deleteAll<T: PersistentModel>(
      matching predicate: Predicate<T>,
      saveNow: Bool = true
   ) throws {
      try deleteAll(
         of: T.self,
         matching: predicate,
         saveNow: saveNow
      )
   }
   // Delete all of a type (optionally with predicate)
   func deleteAll<T: PersistentModel>(
      of type: T.Type,
      matching predicate: Predicate<T>? = nil,
      saveNow: Bool = true
   ) throws {
      let context = modelExecutor.modelContext
      
      try context.delete(
         model: type,
         where: predicate
      )
      
      if saveNow {
         try context.save()
      }
   }
   // Delete all objects
   func deleteAllObjects() throws {
      let context = modelExecutor.modelContext
      
      for model in models {
         try deleteAll(
            of: model,
            saveNow: false
         )
      }
      
      try context.save()
   }
}
