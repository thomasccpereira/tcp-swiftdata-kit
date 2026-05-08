import Foundation
import SQLite3

extension SQLiteValue: Equatable {
   public static func == (lhs: SQLiteValue, rhs: SQLiteValue) -> Bool {
      switch (lhs, rhs) {
      case (.null, .null): return true
      case let (.integer(a), .integer(b)): return a == b
      case let (.real(a), .real(b)): return a == b
      case let (.text(a), .text(b)): return a == b
      case let (.blob(a), .blob(b)): return a == b
      default: return false
      }
   }
}
