# tcp-swiftdata-kit

A Swift actor-based database layer built on top of SwiftData and SQLite3. Provides a clean, type-safe API for CRUD operations, batch upserts, schema migrations, and direct SQLite access — designed with Clean Architecture and strict concurrency in mind.

## Requirements

- iOS 18.0+
- Swift 6.1+

## Dependencies

- [tcp-core-resources](https://github.com/thomasccpereira/tcp-core-resources)
- [tcp-files-kit](https://github.com/thomasccpereira/tcp-files-kit)

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/thomasccpereira/tcp-swiftdata-kit", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

---

## Usage

### Setting up the Database

```swift
let database = try Database(
    models: [UserDAO.self, OrderDAO.self],
    config: DatabaseConfig(configurationName: "main_db")
)
```

With schema migration support:

```swift
let database = try Database(
    currentSchema: AppSchemaV2.self,
    migrationPlan: AppMigrationPlan.self,
    config: DatabaseConfig(configurationName: "main_db")
)
```

In-memory (for tests):

```swift
let database = try Database(
    models: [UserDAO.self],
    config: DatabaseConfig(inMemory: true)
)
```

---

## CRUD Operations

### Fetch

```swift
let users: [User] = try await database.fetch(
    matching: #Predicate<UserDAO> { $0.isActive == true },
    sortBy: [SortDescriptor(\.name)]
)

let first: User? = try await database.first(
    matching: #Predicate<UserDAO> { $0.id == userId }
)
```

### Insert

```swift
// Single
try await database.insert(model: userDTO)

// Batch
let inserted = try await database.batchInsert(userDTOs, batchSize: 500)
```

### Upsert

```swift
// Single — returns true if inserted, false if updated
let wasInserted = try await database.upsert(model: userDTO)

// Batch — returns (updated, inserted) counts
let counts = try await database.batchUpsert(userDTOs)
```

### Update

```swift
// Update all matching
try await database.updateAll(
    matching: #Predicate<UserDAO> { $0.role == "guest" }
) { dao in
    dao.role = "member"
}

// Update first matching
try await database.updateFirst(
    matching: #Predicate<UserDAO> { $0.id == userId }
) { dao in
    dao.name = "New Name"
}
```

### Delete

```swift
// Single
try await database.delete(model: userDTO)

// All matching
try await database.deleteAll(
    matching: #Predicate<UserDAO> { $0.isActive == false }
)

// All of a type
try await database.deleteAll(of: UserDAO.self)

// Everything
try await database.deleteAllObjects()
```

### Save

```swift
try await database.save()
```

---

## Batch Commands

For high-throughput operations, you can compose and run typed `DatabaseCommand` values:

```swift
let commands: [DatabaseCommand] = users.map { user in
    DatabaseCommandUpsert<UserDAO>(
        predicate: #Predicate { $0.id == user.id },
        makeNew: { user.databaseModel },
        apply: { user.applyUpdates(to: $0) }
    )
}

let processed = try await database.run(commands: commands, batchSize: 500)
```

Or use the convenience helpers on `DatabaseModelable`:

```swift
let commands = users.map { $0.asUpsertCommand() }
```

---

## Protocols

### DatabaseModelable

Conform your DTO to `DatabaseModelable` to enable insert and upsert commands:

```swift
struct UserDTO: DatabaseModelable {
    typealias DatabaseModel = UserDAO

    var id: UUID
    var name: String

    var databaseModel: UserDAO {
        UserDAO(id: id, name: name)
    }

    var predicatePrimaryKey: Predicate<UserDAO> {
        let id = self.id
        return #Predicate { $0.id == id }
    }

    func applyUpdates(to model: UserDAO) {
        model.name = name
    }
}
```

### DatabaseUpsertable

Extends `DatabaseModelable` with a `makeNew()` hook for custom DAO creation during upsert:

```swift
struct UserDTO: DatabaseUpsertable {
    func makeNew() -> UserDAO {
        UserDAO(id: id, name: name, createdAt: Date())
    }
}
```

---

## Database State

```swift
// Reset all data (keeps schema)
try await database.reset()

// Delete the SQLite file from disk
try await database.deleteDatabaseFile()
```

---

## Direct SQLite Access

`Database` exposes a `SQLiteDatabase` actor for raw SQL operations — useful for migrations, bulk reads, or queries that SwiftData doesn't support:

```swift
let sqlite = try await database.openSQLite()

// Execute
try await sqlite.exec("INSERT INTO items (id, name) VALUES (?, ?)", [.integer(1), .text("Item")])

// Query
let rows = try await sqlite.query("SELECT * FROM items WHERE id = ?", [.integer(1)])
let name = try rows.first?.string("name")

// Transaction
try await sqlite.withTransaction {
    try await sqlite.exec("UPDATE items SET name = ? WHERE id = ?", [.text("Updated"), .integer(1)])
}
```

### SQLiteValue types

| Case | Swift type |
|---|---|
| `.null` | — |
| `.integer(Int64)` | `Int`, `Int64`, `Bool` |
| `.real(Double)` | `Double` |
| `.text(String)` | `String`, `UUID`, `Date` |
| `.blob(Data)` | `Data` |

### SQLiteRow typed accessors

```swift
let row: SQLiteRow = ...
let id: Int    = try row.int("id")
let name: String = try row.string("name")
let active: Bool = try row.bool("is_active", default: false)
let uuid: UUID   = try row.uuid("external_id")
```

---

## Error Handling

All SwiftData operations throw `DatabaseError`:

| Case | Description |
|---|---|
| `.invalidContainerPath` | Configuration name is empty |
| `.containerCreationFailed(underlying:)` | `ModelContainer` init failed |
| `.sqliteDatabaseWrapperCreationFailed` | Could not open raw SQLite connection |
| `.databaseOperationFails(action:objectType:)` | CRUD operation failed |
| `.objectNotFound(detail:)` | Expected record not found |
| `.genericError(error:)` | Unexpected error |

Raw SQLite operations throw `SQLiteError` with detailed codes and messages from `sqlite3_errmsg`.

---

## License

MIT
