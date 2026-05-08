import Foundation

// Values you can bind to SQLite statements or read from rows.
public enum SQLiteValue: Sendable {
   case null
   case integer(Int64)
   case real(Double)
   case text(String)
   case blob(Data)
   
   public init<T: BinaryInteger>(_ value: T) {
      self = .integer(Int64(value))
   }
   
   public init<T: BinaryFloatingPoint>(_ value: T) {
      self = .real(Double(value))
   }
}
