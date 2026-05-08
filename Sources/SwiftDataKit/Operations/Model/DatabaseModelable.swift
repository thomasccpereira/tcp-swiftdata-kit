import SwiftData
import Foundation

public protocol DatabaseModelable: Sendable {
   associatedtype DatabaseModel: PersistentModel
   var databaseModel: DatabaseModel { get }
   var predicatePrimaryKey: Predicate<DatabaseModel> { get }
   
   func applyUpdates(to model: DatabaseModel)
}

public extension DatabaseModelable {
   func asUpsertCommand() -> DatabaseCommand {
      DatabaseCommandUpsert<DatabaseModel>(predicate: predicatePrimaryKey,
                                           makeNew: { self.databaseModel },
                                           apply: { self.applyUpdates(to: $0) })
   }
   
   // If you need insert-only behavior.
   func asInsertCommand() -> DatabaseCommand {
      DatabaseCommandInsert<DatabaseModel>(makeNew: { self.databaseModel })
   }
}
