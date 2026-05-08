import Foundation

public struct DatabaseConfig: Sendable {
   public enum DatabaseDefaults {
      public static let defaultDatabaseName = "main_db"
      public static let accountDatabaseName = "%@_%@_db"
      public static let sqliteExtension = "sqlite"
   }
   
   public var inMemory: Bool
   public var configurationName: String
   
   public init(inMemory: Bool = false,
               configurationName: String = DatabaseDefaults.defaultDatabaseName) {
      self.inMemory = inMemory
      self.configurationName = configurationName
   }
}
