import SwiftData
import Foundation
@testable import CoreResources

// MARK: - DummyDetail DAO
@Model
final class DummyDetailDAO {
   @Attribute(.unique) var id: UUID
   var note: String
   var image: Data?
   var rating: Double?
   
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

extension DummyDetailDAO: DomainModelable {
   typealias DomainModel = DummyDetailModel
   
   var domainModel: DummyDetailModel {
      .init(id: id,
            note: note,
            image: image,
            rating: rating)
   }
}

// MARK: - DummyItem  DAO
@Model
final class DummyItemDAO {
   @Attribute(.unique) var id: UUID
   var title: String
   var tags: String
   var separatedTags: [String] {
      tags.components(separatedBy: ", ")
   }
   @Relationship(deleteRule: .cascade) var detail: DummyDetailDAO?
   
   init(id: UUID = .init(),
        title: String,
        tags: [String] = [],
        detail: DummyDetailDAO? = nil) {
      self.id = id
      self.title = title
      self.tags = tags.joined(separator: ", ")
      self.detail = detail
   }
}

extension DummyItemDAO: DomainModelable {
   typealias DomainModel = DummyItemModel
   
   var domainModel: DummyItemModel {
      return DummyItemModel(id: id,
                            title: title,
                            tags: separatedTags,
                            detail: detail?.domainModel)
   }
}
