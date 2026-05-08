import SwiftData
import Foundation

// Generic upsert command for a specific DAO type.
/// - No MainActor.
/// - All SwiftData work happens when `perform` is called inside the model actor.
public struct DatabaseCommandUpsert<DAO: PersistentModel>: DatabaseCommand, Sendable {
   public let predicate: Predicate<DAO>
   public let makeNew: @Sendable () -> DAO
   public let apply: @Sendable (DAO) -> Void
   
   public init(predicate: Predicate<DAO>,
               makeNew: @Sendable @escaping () -> DAO,
               apply: @Sendable @escaping (DAO) -> Void) {
      self.predicate = predicate
      self.makeNew = makeNew
      self.apply = apply
   }
   
   public func perform(in context: ModelContext) throws {
      var descriptor = FetchDescriptor<DAO>(predicate: predicate)
      descriptor.fetchLimit = 1
      
      if let existing = try context.fetch(descriptor).first {
         apply(existing)
         
      } else {
         let obj = makeNew()
         context.insert(obj)
      }
   }
}
