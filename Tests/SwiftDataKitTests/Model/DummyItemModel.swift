import Foundation

// MARK: - DummyDetail domain model
struct DummyDetailModel {
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

// MARK: - DummyItem domain model
struct DummyItemModel {
   let id: UUID
   let title: String
   let tags: [String]
   var joinedTags: String { tags.joined(separator: ", ") }
   let detail: DummyDetailModel?
   
   init(id: UUID = .init(),
        title: String,
        tags: [String],
        detail: DummyDetailModel?) {
      self.id = id
      self.title = title
      self.tags = tags
      self.detail = detail
   }
}
