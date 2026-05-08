import Foundation
import SQLite3

public extension UUID {
   init(sqliteValue: SQLiteValue?) throws {
      switch sqliteValue {
      case .text(let string):
         guard let uuid = UUID(uuidString: string) else {
            throw SQLiteError.bindFailed(index: 0,
                                         code: SQLITE_MISMATCH,
                                         message: "Bad UUID '\(string)'")
         }
         self = uuid
         
      case .blob(let data) where data.count == 16:
         self = data.withUnsafeBytes { ptr in
            let t = ptr.bindMemory(to: UInt8.self)
            return UUID(uuid: (
               t[0], t[1], t[2], t[3],
               t[4], t[5],
               t[6], t[7],
               t[8], t[9],
               t[10], t[11], t[12], t[13], t[14], t[15]
            ))
         }
         
      default:
         throw SQLiteError.bindFailed(index: 0,
                                      code: SQLITE_MISMATCH,
                                      message: "Expected UUID, got \(String(describing: sqliteValue))")
      }
   }
   
   init(sqliteValue: SQLiteValue?, default defaultValue: @autoclosure () -> UUID) throws {
      guard let value = sqliteValue, value != .null else {
         self = defaultValue()
         return
      }
      
      self = try UUID(sqliteValue: value)
   }
}
