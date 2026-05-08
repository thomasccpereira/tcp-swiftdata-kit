import Foundation
import SQLite3
import CoreResources

public extension AnyDate {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .integer(let integer):
         let date = Date(timeIntervalSinceReferenceDate: Double(integer))
         self = try AnyDate(dateValue: date)
         
      case .real(let double):
         let date = Date(timeIntervalSinceReferenceDate: double)
         self = try AnyDate(dateValue: date)
         
      case .text(let string):
         let dateFromString = string.date
         self = try AnyDate(dateValue: dateFromString)
         
      case .null, .blob, nil:
         self = try AnyDate()
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> AnyDate) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try AnyDate(sqliteValue: value)
   }
}
