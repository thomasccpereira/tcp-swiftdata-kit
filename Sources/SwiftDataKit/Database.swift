import SwiftData
import Foundation
import FilesKit
import CoreResources

public actor Database: ModelActor, FilesDirectory {
   public nonisolated let modelContainer: ModelContainer
   public nonisolated let modelExecutor: any ModelExecutor
   public let databaseStoreURL: URL?
   nonisolated let models: [any PersistentModel.Type]
   nonisolated let config: DatabaseConfig
   
   public init(
      models: [any PersistentModel.Type],
      config: DatabaseConfig = .init()
   ) throws {
      let configuration = try Self.makeConfiguration(config: config)
      let storeURL = try Self.makeStoreURL(config: config)

      let modelContainer = try ModelContainer(for: Schema(models), configurations: configuration)
      let modelContext = ModelContext(modelContainer)
      self.modelContainer = modelContainer
      self.modelExecutor  = DefaultSerialModelExecutor(modelContext: modelContext)
      self.databaseStoreURL = storeURL
      self.models = models
      self.config = config
   }

   /// Initializes the database using a `VersionedSchema` and `SchemaMigrationPlan`,
   /// enabling SwiftData to automatically run any pending migrations on launch.
   public init(
      currentSchema: any VersionedSchema.Type,
      migrationPlan: any SchemaMigrationPlan.Type,
      config: DatabaseConfig = .init()
   ) throws {
      let configuration = try Self.makeConfiguration(config: config)
      let storeURL = try Self.makeStoreURL(config: config)

      let schema = Schema(versionedSchema: currentSchema)
      let modelContainer = try ModelContainer(
         for: schema,
         migrationPlan: migrationPlan,
         configurations: configuration
      )
      let modelContext = ModelContext(modelContainer)
      self.modelContainer = modelContainer
      self.modelExecutor  = DefaultSerialModelExecutor(modelContext: modelContext)
      self.databaseStoreURL = storeURL
      self.models = currentSchema.models
      self.config = config
   }

   // MARK: - Private helpers

   private static func makeConfiguration(config: DatabaseConfig) throws -> ModelConfiguration {
      if config.inMemory {
         return ModelConfiguration(config.configurationName, isStoredInMemoryOnly: true)
      } else if !config.configurationName.isEmpty {
         let url = try makeStoreURL(config: config)!
         return ModelConfiguration(config.configurationName, url: url)
      } else {
         throw DatabaseError.invalidContainerPath
      }
   }

   private static func makeStoreURL(config: DatabaseConfig) throws -> URL? {
      guard !config.inMemory else { return nil }
      guard !config.configurationName.isEmpty else { throw DatabaseError.invalidContainerPath }
      let storeURL = try Self.applicationSupport
         .appending(path: config.configurationName)
         .appendingPathExtension(DatabaseConfig.DatabaseDefaults.sqliteExtension)
      return storeURL
   }
   
   public func openSQLite() throws -> SQLiteDatabase {
      let sqlitePath = databaseStoreURL?.path(percentEncoded: false) ?? ""
      guard let sqliteConfig = SQLiteConfiguration(path: sqlitePath, inMemory: config.inMemory) else {
         throw DatabaseError.sqliteDatabaseWrapperCreationFailed
      }
      return try SQLiteDatabase(config: sqliteConfig)
   }
}
