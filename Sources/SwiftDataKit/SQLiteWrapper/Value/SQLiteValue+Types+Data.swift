import Foundation
import SQLite3

public extension Data {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .blob(let data):
         self = data
         
      case .text(let string):
         self = Data(string.utf8)
         
      default:
         throw SQLiteError.bindFailed(index: 0,
                                      code: SQLITE_MISMATCH,
                                      message: "Expected BLOB, got \(String(describing: sqliteValue))")
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> Data) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try Data(sqliteValue: value)
   }
}
