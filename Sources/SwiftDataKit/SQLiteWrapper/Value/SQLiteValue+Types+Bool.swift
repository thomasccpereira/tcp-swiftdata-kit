import Foundation
import SQLite3
import CoreResources

public extension Bool {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .integer(let integer):
         self = (integer != 0)
         
      case .real(let double):
         self = (Int(double) != 0)
         
      case .text(let string):
         let lower = string.lowercased()
         let anyBool = try AnyBool(stringValue: lower)
         self = anyBool.wrappedValue
         
      case .null, .blob, nil:
         self = false
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> Bool) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try Bool(sqliteValue: value)
   }
}

public extension AnyBool {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .integer(let integer):
         let bool = (integer != 0)
         self = try AnyBool(boolValue: bool)
         
      case .real(let double):
         let bool = (Int(double) != 0)
         self = try AnyBool(boolValue: bool)
         
      case .text(let string):
         let lower = string.lowercased()
         self = try AnyBool(stringValue: lower)
         
      case .null, .blob, nil:
         self = try AnyBool(boolValue: false)
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> AnyBool) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try AnyBool(sqliteValue: value)
   }
}
