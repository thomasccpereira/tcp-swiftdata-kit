import Foundation
import SQLite3

public extension Double {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .real(let double):
         self = double
         
      case .integer(let integer):
         self = Double(integer)
         
      case .text(let string):
         guard let doubleFromString = Double(string) else {
            throw SQLiteError.bindFailed(index: 0,
                                         code: SQLITE_MISMATCH,
                                         message: "Cannot convert text '\(string)' to Double")
         }
         self = doubleFromString
         
      case .null, .blob, nil:
         throw SQLiteError.bindFailed(index: 0,
                                      code: SQLITE_MISMATCH,
                                      message: "Expected Double, got \(String(describing: sqliteValue))")
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> Double) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try Double(sqliteValue: value)
   }
}
