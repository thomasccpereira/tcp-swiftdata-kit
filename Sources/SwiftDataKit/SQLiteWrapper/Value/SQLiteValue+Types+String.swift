import Foundation
import SQLite3

public extension String {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .text(let string):
         self = string
         
      case .integer(let integer):
         self = String(integer)
         
      case .real(let double):
         self = String(double)
         
      case .blob(let data):
         self = data.base64EncodedString()
         
      case .null, nil:
         self = "" // default empty string for NULL
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> String) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try String(sqliteValue: value)
   }
}
