import Foundation
import SQLite3

public struct SQLiteConfiguration: Sendable, Equatable {
   public enum JournalMode: String, Sendable {
      case wal = "WAL"
      case delete = "DELETE"
      case truncate = "TRUNCATE"
      case persist = "PERSIST"
      case memory = "MEMORY"
      case off = "OFF"
   }
   
   public var path: String
   public var inMemory: Bool
   public var readOnly: Bool
   public var createIfMissing: Bool
   public var busyTimeoutMillis: Int32
   public var journalMode: JournalMode
   public var foreignKeys: Bool
   
   public init?(path: String = "",
                inMemory: Bool = false,
                readOnly: Bool = false,
                createIfMissing: Bool = true,
                busyTimeoutMillis: Int32 = 5_000,
                journalMode: JournalMode = .wal,
                foreignKeys: Bool = true) {
      let inMemoryOnly = path.isEmpty && inMemory
      
      if path.isEmpty && !inMemory {
         return nil
      }
      
      let pathOrMemory = inMemoryOnly ? ":memory:" : path
      self.path = pathOrMemory
      self.inMemory = inMemory
      self.readOnly = readOnly
      self.createIfMissing = createIfMissing
      self.busyTimeoutMillis = busyTimeoutMillis
      self.journalMode = journalMode
      self.foreignKeys = foreignKeys
   }
}
