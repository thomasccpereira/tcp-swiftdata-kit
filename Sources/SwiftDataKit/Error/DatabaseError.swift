import Foundation
import CoreResources

public enum DatabaseError: Error, LocalizedError, Equatable {
   public enum DatabaseActions: Sendable {
      case insert
      case select
      case update
      case delete
      case save
      
      public var statement: String {
         switch self {
         case .insert: "INSERT"
         case .select: "SELECT"
         case .update: "UPDATE"
         case .delete: "DELETE"
         case .save: "COMMIT"
         }
      }
   }
   
   public static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.genericError(let lError), .genericError(let rError)): lError.localizedDescription == rError.localizedDescription
      case (.invalidContainerPath, .invalidContainerPath): true
      case (.containerCreationFailed(let lError), .containerCreationFailed(let rError)): lError.localizedDescription == rError.localizedDescription
      case (.sqliteDatabaseWrapperCreationFailed, .sqliteDatabaseWrapperCreationFailed): true
      case (.databaseOperationFails(let lAction, let lObject), .databaseOperationFails(let rAction, let rObject)): lAction == rAction && lObject == rObject
      case (.objectNotFound(let lDetail), .objectNotFound(let rDetail)): lDetail == rDetail
      default: false
      }
   }
   
   case genericError(error: Error)
   case invalidContainerPath
   case containerCreationFailed(underlying: Error)
   case sqliteDatabaseWrapperCreationFailed
   case databaseOperationFails(action: DatabaseActions, objectType: String)
   case objectNotFound(detail: String)
   
   public var errorDescription: String? {
      switch self {
      case .genericError(let error): localized("database_error_unknown", args: error.localizedDescription, bundle: .module)
      case .invalidContainerPath: ""
      case .containerCreationFailed(let underlying): localized("database_error_creation", args: underlying.localizedDescription, bundle: .module)
      case .sqliteDatabaseWrapperCreationFailed: localized("sqlite_error_in_memory", bundle: .module)
      case .databaseOperationFails(let action, let objectType): localized("database_error_crud", args: action.statement, objectType, bundle: .module)
      case .objectNotFound(let detail): detail
      }
   }
}
