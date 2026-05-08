import Foundation
@testable import SwiftDataKit

// MARK: - DummyDetail DTO
struct DummyDetailDTO: Sendable, Equatable {
   let id: UUID
   let note: String
   let image: Data?
   let rating: Double?
   
   init(id: UUID = .init(),
        note: String,
        image: Data? = nil,
        rating: Double? = nil) {
      self.id = id
      self.note = note
      self.image = image
      self.rating = rating
   }
}

extension DummyDetailDTO: DatabaseUpsertable {
   typealias DatabaseModel = DummyDetailDAO
   
   var databaseModel: DummyDetailDAO {
      .init(id: id,
            note: note,
            image: image,
            rating: rating)
   }
   
   var predicatePrimaryKey: Predicate<DummyDetailDAO> {
      let key = id
      return #Predicate<DummyDetailDAO> { $0.id == key }
   }
   
   func applyUpdates(to model: DummyDetailDAO) {
      model.note = note
      model.image = image
      model.rating = rating
   }
   
   func makeNew() -> DummyDetailDAO {
      databaseModel
   }
}

// MARK: - DummyItem DTO
struct DummyItemDTO: Sendable, Equatable {
   let id: UUID
   var title: String
   let tags: [String]
   var joinedTags: String { tags.joined(separator: ", ") }
   var detail: DummyDetailDTO?
   
   init(id: UUID = .init(),
        title: String,
        tags: [String] = [],
        detail: DummyDetailDTO? = nil) {
      self.id = id
      self.title = title
      self.tags = tags
      self.detail = detail
   }
}

extension DummyItemDTO: DatabaseUpsertable {
   typealias DatabaseModel = DummyItemDAO
   
   var databaseModel: DummyItemDAO {
      DummyItemDAO(id: id,
                   title: title,
                   tags: tags,
                   detail: detail?.databaseModel)
   }
   
   var predicatePrimaryKey: Predicate<DummyItemDAO> {
      let key = id
      return #Predicate<DummyItemDAO> { $0.id == key }
   }
   
   func applyUpdates(to model: DummyItemDAO) {
      model.title = title
      model.tags = joinedTags
      if let note = detail?.note {
         if model.detail == nil {
            model.detail = DummyDetailDAO(note: note)
         }
         model.detail?.note = note
      } else {
         model.detail = nil
      }
   }
   
   func makeNew() -> DummyItemDAO {
      databaseModel
   }
}

