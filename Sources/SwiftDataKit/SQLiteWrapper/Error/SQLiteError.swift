import Foundation
import SQLite3
import CoreResources

public enum SQLiteError: Error, LocalizedError, Sendable {
   case openFailed(path: String, code: Int32, message: String)
   case prepareFailed(sql: String, code: Int32, message: String)
   case bindFailed(index: Int32, code: Int32, message: String)
   case stepFailed(sql: String, code: Int32, message: String)
   case finalizeFailed(code: Int32)
   case unknown(code: Int32, message: String)
   
   public var errorDescription: String? {
      switch self {
      case let .openFailed(path, code, message): localized("sqlite_error_open_failed", args: code, path, message, bundle: .module)
      case let .prepareFailed(sql, code, message): localized("sqlite_error_prepare_failed", args: code, sql, message, bundle: .module)
      case let .bindFailed(index, code, message): localized("sqlite_error_bind_failed", args: index, code, message, bundle: .module)
      case let .stepFailed(sql, code, message): localized("sqlite_error_step_failed", args: sql, code, message, bundle: .module)
      case let .finalizeFailed(code): localized("sqlite_error_finalize_failed", args: code, bundle: .module)
      case let .unknown(code, message): localized("sqlite_error_unknown", args: code, message, bundle: .module)
      }
   }
}
