import SwiftData

// Adds the “update existing” behavior. No MainActor here;
// the mutation will happen inside the background model actor.
public protocol DatabaseUpsertable: DatabaseModelable {
   // Mutate an existing model to reflect the DTO.
   func applyUpdates(to model: DatabaseModel)
   
   // Optional hook to customize creation; default uses `databaseModel`.
   func makeNew() -> DatabaseModel
}

public extension DatabaseUpsertable {
   func makeNew() -> DatabaseModel { databaseModel }
}
