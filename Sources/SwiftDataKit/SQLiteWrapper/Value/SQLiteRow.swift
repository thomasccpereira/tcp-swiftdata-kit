import Foundation

/// Row returned from a SELECT. It is detached from SQLite state and thus `Sendable`.
public struct SQLiteRow: Sendable, Equatable {
   public let columns: [String]
   public let values: [SQLiteValue]
   
   public subscript(_ name: String) -> SQLiteValue? {
      guard let idx = columns.firstIndex(of: name) else { return nil }
      return values[idx]
   }
   
   public subscript(_ index: Int) -> SQLiteValue? {
      guard index >= 0 && index < values.count else { return nil }
      return values[index]
   }
   
   public func int64(_ name: String) -> Int64? {
      (self[name]).flatMap {
         if case let .integer(intValue) = $0 {
            return intValue
         } else {
            return nil
         }
      }
   }
   
   public func double(_ name: String) -> Double? {
      (self[name]).flatMap {
         if case let .real(doubleValue) = $0 {
            return doubleValue
         } else {
            return nil
         }
      }
   }
   
   public func string(_ name: String) -> String? {
      (self[name]).flatMap {
         if case let .text(stringValue) = $0 {
            return stringValue
         } else {
            return nil
         }
      }
   }
   
   public func data(_ name: String) -> Data? {
      (self[name]).flatMap {
         if case let .blob(dataValue) = $0 {
            return dataValue
         } else {
            return nil
         }
      }
   }
}
