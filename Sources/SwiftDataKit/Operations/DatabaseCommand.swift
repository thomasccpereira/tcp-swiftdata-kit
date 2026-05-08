import SwiftData
import Foundation

// The type-erased operation we’ll batch execute inside the model actor.
public protocol DatabaseCommand: Sendable {
   func perform(in context: ModelContext) throws
}
