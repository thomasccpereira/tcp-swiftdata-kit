import SwiftData
import Foundation
import CoreResources

public extension Database {
   @discardableResult
   func updateAll<T: PersistentModel>(
      matching predicate: Predicate<T>? = nil,
      mutate: @Sendable (inout T) -> Void
   ) async throws -> Int {
      let context = modelExecutor.modelContext
      
      let objects = try fetchDAO(matching: predicate)
      for var object in objects {
         mutate(&object)
      }
      
      if !objects.isEmpty {
         try context.save()
      }
      
      return objects.count
   }
   
   @discardableResult
   func updateFirst<T: PersistentModel>(
      matching predicate: Predicate<T>,
      mutate: @Sendable (inout T) -> Void
   ) async throws -> Bool {
      let context = modelExecutor.modelContext
      
      if var object = try firstDAO(matching: predicate) {
         mutate(&object)
         try context.save()
         return true
      }
      
      return false
   }
}
