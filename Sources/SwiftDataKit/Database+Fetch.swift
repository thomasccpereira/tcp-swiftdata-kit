import SwiftData
import Foundation
import CoreResources

public extension Database {
   func fetch<T>(
      columns: [PartialKeyPath<T>]? = nil,
      matching predicate: Predicate<T>? = nil,
      sortBy: [SortDescriptor<T>] = [],
      limit: Int? = nil,
      offset: Int = 0
   ) throws -> [T.DomainModel] where T: PersistentModel & DomainModelable {
      let context = modelExecutor.modelContext
      
      var fetchDescriptor = FetchDescriptor<T>(predicate: predicate,
                                               sortBy: sortBy)
      // Columns
      if let columns, !columns.isEmpty {
         fetchDescriptor.propertiesToFetch = columns
      }
      // Limit
      if let limit {
         fetchDescriptor.fetchLimit = limit
      }
      // Offset
      fetchDescriptor.fetchOffset = offset
      
      let results = try context.fetch(fetchDescriptor)
      if let columns, !columns.isEmpty {
         return results.map(\.essentialDomainModel)
      }
      
      return results.map(\.domainModel)
   }
   
   func first<T>(
      columns: [PartialKeyPath<T>]? = nil,
      matching predicate: Predicate<T>,
      sortBy: [SortDescriptor<T>] = []
   ) throws -> T.DomainModel? where T: PersistentModel & DomainModelable {
      try fetch(
         columns: columns,
         matching: predicate,
         sortBy: sortBy,
         limit: 1
      ).first
   }
   
   func count<T: PersistentModel>(
      of type: T.Type,
      matching predicate: Predicate<T>
   ) throws -> Int where T: PersistentModel & DomainModelable {
      try fetch(matching: predicate).count
   }
}

// MARK: - Internal DAO fetchers — used by update APIs
package extension Database {
   func fetchDAO<T: PersistentModel>(
      matching predicate: Predicate<T>? = nil,
      sortBy: [SortDescriptor<T>] = [],
      limit: Int? = nil,
      offset: Int = 0
   ) throws -> [T] {
      let context = modelExecutor.modelContext
      
      var fetchDescriptor = FetchDescriptor<T>(predicate: predicate,
                                               sortBy: sortBy)
      if let limit {
         fetchDescriptor.fetchLimit = limit
      }
      fetchDescriptor.fetchOffset = offset
      
      return try context.fetch(fetchDescriptor)
   }
   
   func firstDAO<T: PersistentModel>(
      matching predicate: Predicate<T>,
      sortBy: [SortDescriptor<T>] = []
   ) throws -> T? {
      try fetchDAO(
         matching: predicate,
         sortBy: sortBy,
         limit: 1
      ).first
   }
}
