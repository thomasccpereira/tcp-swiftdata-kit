import SwiftData
import Foundation
import FilesKit

public extension Database {
   func reset() throws -> Bool {
      do {
         try deleteAllObjects()
         return true
         
      } catch {
         let modelsString = self.models.map { String(describing: $0.self) }.joined(separator: ", ")
         throw DatabaseError.databaseOperationFails(
            action: .delete,
            objectType: modelsString
         )
      }
   }
   
   func deleteDatabaseFile() throws -> Bool {
      guard let databaseStoreURL else { return true }
      
      do {
         let files = Files()
         try files.deleteFile(originalURL: databaseStoreURL, andVariations: true)
         return true
         
      } catch {
         throw DatabaseError.genericError(
            error: error
         )
      }
   }
}
