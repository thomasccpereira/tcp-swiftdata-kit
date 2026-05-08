import Foundation

enum TestPaths {
   static func temporaryFile(_ name: String = UUID().uuidString, ext: String = "sqlite") -> URL {
      let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      return base.appendingPathComponent(name).appendingPathExtension(ext)
   }
}
