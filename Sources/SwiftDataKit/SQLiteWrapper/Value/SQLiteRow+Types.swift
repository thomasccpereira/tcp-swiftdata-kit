import Foundation
import CoreResources

public extension SQLiteRow {
   // MARK: - No default values
   func int(_ column: String) throws -> Int { try Int(sqliteValue: self[column]) }
   func int64(_ column: String) throws -> Int64 { try Int64(sqliteValue: self[column]) }
   func double(_ column: String) throws -> Double { try Double(sqliteValue: self[column]) }
   func string(_ column: String) throws -> String { try String(sqliteValue: self[column]) }
   func bool(_ column: String) throws -> Bool { try Bool(sqliteValue: self[column]) }
   func anyBool(_ column: String) throws -> AnyBool { try AnyBool(sqliteValue: self[column]) }
   func anyDate(_ column: String) throws -> AnyDate { try AnyDate(sqliteValue: self[column]) }
   func uuid(_ column: String) throws -> UUID { try UUID(sqliteValue: self[column]) }
   func data(_ column: String) throws -> Data { try Data(sqliteValue: self[column]) }
   
   // MARK: - With default values
   func int(_ column: String, default def: @autoclosure () -> Int) throws -> Int { try Int(sqliteValue: self[column], default: def()) }
   func int64(_ column: String, default def: @autoclosure () -> Int64) throws -> Int64 { try Int64(sqliteValue: self[column], default: def()) }
   func double(_ column: String, default def: @autoclosure () -> Double) throws -> Double { try Double(sqliteValue: self[column], default: def()) }
   func string(_ column: String, default def: @autoclosure () -> String) throws -> String { try String(sqliteValue: self[column], default: def()) }
   func bool(_ column: String, default def: @autoclosure () -> Bool) throws -> Bool { try Bool(sqliteValue: self[column], default: def()) }
   func anyBool(_ column: String, default def: @autoclosure () -> AnyBool) throws -> AnyBool { try AnyBool(sqliteValue: self[column], default: def()) }
   func anyDate(_ column: String, default def: @autoclosure () -> AnyDate) throws -> AnyDate { try AnyDate(sqliteValue: self[column], default: def()) }
   func uuid(_ column: String, default def: @autoclosure () -> UUID) throws -> UUID { try UUID(sqliteValue: self[column], default: def()) }
   func data(_ column: String, default def: @autoclosure () -> Data) throws -> Data { try Data(sqliteValue: self[column], default: def()) }
}
