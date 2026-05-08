import SwiftData
import Foundation

public extension Database {
   /// Executes a closure directly on the model context, useful for operations
   /// that require relationship linking or multi-model coordination.
   /// The closure runs on the actor's executor so all context access is safe.
   func perform<T>(_ work: (ModelContext) throws -> T) throws -> T {
      try work(modelExecutor.modelContext)
   }

   @discardableResult
   func run(
      commands: [DatabaseCommand],
      batchSize: Int = 500
   ) throws -> Int {
      let context = modelExecutor.modelContext
      var processed = 0
      var sinceSave = 0
      
      for command in commands {
         try command.perform(in: context)
         processed += 1
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
      
      return processed
   }
}
