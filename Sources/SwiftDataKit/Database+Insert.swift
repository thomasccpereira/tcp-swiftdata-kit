import SwiftData
import Foundation
import CoreResources

public extension Database {
   // MARK: - Insert
   // Single insert
   func insert<T>(
      model: T
   ) throws -> T where T: DatabaseUpsertable {
      let context = modelExecutor.modelContext
      
      let dao = model.databaseModel
      context.insert(dao)
      try context.save()
      
      return model
   }
   // Batch insert
   func batchInsert<M: DatabaseModelable>(
      _ models: [M],
      batchSize: Int = 500
   ) throws -> Int {
      let context = modelExecutor.modelContext
      var inserted = 0
      var sinceSave = 0
      
      for model in models {
         let dao = model.databaseModel
         context.insert(dao)
         inserted += 1
         sinceSave += 1
         
         if sinceSave >= batchSize {
            try context.save()
            sinceSave = 0
            try Task.checkCancellation()
         }
      }
      
      if sinceSave > 0 {
         try context.save()
      }
      
      return inserted
   }
   
   // MARK: - Upsert
   // Single upsert
   func upsert<T>(
      model: T
   ) throws -> Bool where T: DatabaseUpsertable {
      let context = modelExecutor.modelContext
      
      var fetchDescriptor = FetchDescriptor<T.DatabaseModel>(predicate: model.predicatePrimaryKey)
      fetchDescriptor.fetchLimit = 1
      
      if let existing = try modelContext.fetch(fetchDescriptor).first {
         model.applyUpdates(to: existing)
         try context.save()
         return false
         
      } else {
         context.insert(model.databaseModel)
         try context.save()
         return true
      }
   }
   // Bacth updsert
   @discardableResult
   func batchUpsert<M: DatabaseUpsertable>(
      _ models: [M],
      batchSize: Int = 500
   ) throws -> (updated: Int, inserted: Int) {
      let context = modelExecutor.modelContext
      var updated = 0
      var inserted = 0
      var sinceSave = 0
      
      for model in models {
         var fetchDescriptor = FetchDescriptor<M.DatabaseModel>(predicate: model.predicatePrimaryKey)
         fetchDescriptor.fetchLimit = 1
         
         if let existing = try context.fetch(fetchDescriptor).first {
            model.applyUpdates(to: existing)
            updated += 1
            
         } else {
            context.insert(model.makeNew())
            inserted += 1
         }
         
         sinceSave += 1
         if sinceSave >= batchSize {
            try context.save()
            sinceSave = 0
            try Task.checkCancellation()
         }
      }
      
      if sinceSave > 0 {
         try context.save()
      }
      
      return (updated, inserted)
   }
}
