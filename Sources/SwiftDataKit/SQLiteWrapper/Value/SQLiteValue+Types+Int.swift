import Foundation
import SQLite3

public extension Int {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .integer(let integer):
         self = Int(integer)
         
      case .real(let double):
         self = Int(double)
         
      case .text(let string):
         guard let intFromString = Int(string) else {
            throw SQLiteError.bindFailed(index: 0,
                                         code: SQLITE_MISMATCH,
                                         message: "Cannot convert text '\(string)' to Int")
         }
         self = intFromString
         
      case .null, .blob, nil:
         throw SQLiteError.bindFailed(index: 0,
                                      code: SQLITE_MISMATCH,
                                      message: "Expected Int, got \(String(describing: sqliteValue))")
      }
   }
   
   /// Uses `default` when value is `nil` or `.null`. Still throws on type/parse mismatch.
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> Int) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try Int(sqliteValue: value)
   }
}

public extension Int64 {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .integer(let integer):
         self = integer
         
      case .real(let double):
         self = Int64(double)
         
      case .text(let string):
         guard let intFromString = Int64(string) else {
            throw SQLiteError.bindFailed(index: 0,
                                         code: SQLITE_MISMATCH,
                                         message: "Cannot convert text '\(string)' to Int")
         }
         self = intFromString
         
      case .null, .blob, nil:
         throw SQLiteError.bindFailed(index: 0,
                                      code: SQLITE_MISMATCH,
                                      message: "Expected Int, got \(String(describing: sqliteValue))")
      }
   }
   
   /// Uses `default` when value is `nil` or `.null`. Still throws on type/parse mismatch.
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> Int64) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try Int64(sqliteValue: value)
   }
}
