import SwiftData
import Foundation

// Pure insert (no lookup). Handy for append-only tables.
public struct DatabaseCommandInsert<DAO: PersistentModel>: DatabaseCommand, Sendable {
   public let makeNew: @Sendable () -> DAO
   
   public init(makeNew: @Sendable @escaping () -> DAO) {
      self.makeNew = makeNew
   }
   
   public func perform(in context: ModelContext) throws {
      context.insert(makeNew())
   }
}
