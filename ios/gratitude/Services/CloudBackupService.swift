import Foundation
import CloudKit
import CryptoKit
import SwiftData

/// On-demand, client-side-encrypted backup to the user's own private CloudKit
/// database. Apple/CloudKit only ever sees ciphertext (`AES.GCM`), the key
/// lives in the Keychain via `EncryptionKeyStore`. This is not a live sync
/// engine — it's an explicit "Sync Now" / "Restore from iCloud" pair invoked
/// from Settings.
final class CloudBackupService {
    static let shared = CloudBackupService()

    private let container = CKContainer(identifier: "iCloud.com.sachabest.gratitude")
    private let recordType = "EncryptedEntry"

    private init() {}

    enum BackupError: LocalizedError {
        case notSignedIn
        case encryptionFailed

        var errorDescription: String? {
            switch self {
            case .notSignedIn: "Sign in to iCloud in Settings to use encrypted backup."
            case .encryptionFailed: "Couldn't encrypt your data."
            }
        }
    }

    func accountStatus() async -> CKAccountStatus {
        (try? await container.accountStatus()) ?? .couldNotDetermine
    }

    @discardableResult
    func backupAll(context: ModelContext) async throws -> Int {
        guard await accountStatus() == .available else { throw BackupError.notSignedIn }
        let key = try EncryptionKeyStore.loadOrCreateKey()
        let database = container.privateCloudDatabase

        let checkIns = try context.fetch(FetchDescriptor<CheckIn>())
        let smiles = try context.fetch(FetchDescriptor<Smile>())

        var records: [CKRecord] = []
        for checkIn in checkIns {
            let dto = CheckInDTO(from: checkIn)
            records.append(try makeRecord(name: "checkin-\(dto.id.uuidString)", kind: "checkIn", payload: dto, updatedAt: dto.updatedAt, key: key))
        }
        for smile in smiles {
            let dto = SmileDTO(from: smile)
            records.append(try makeRecord(name: "smile-\(dto.id.uuidString)", kind: "smile", payload: dto, updatedAt: dto.date, key: key))
        }

        for chunk in records.chunked(into: 200) {
            try await save(chunk, to: database)
        }
        return records.count
    }

    @discardableResult
    func restoreAll(context: ModelContext) async throws -> Int {
        guard await accountStatus() == .available else { throw BackupError.notSignedIn }
        let key = try EncryptionKeyStore.loadOrCreateKey()
        let database = container.privateCloudDatabase

        let existingCheckInIDs = Set(try context.fetch(FetchDescriptor<CheckIn>()).map(\.id))
        let existingSmileIDs = Set(try context.fetch(FetchDescriptor<Smile>()).map(\.id))

        var cursor: CKQueryOperation.Cursor?
        var restoredCount = 0
        var isFirstPage = true

        while isFirstPage || cursor != nil {
            isFirstPage = false
            let (matchResults, nextCursor): ([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?)
            if let cursor {
                (matchResults, nextCursor) = try await database.records(continuingMatchFrom: cursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                (matchResults, nextCursor) = try await database.records(matching: query)
            }
            cursor = nextCursor

            for (_, result) in matchResults {
                guard let record = try? result.get(),
                      let kind = record["kind"] as? String,
                      let payload = record["payload"] as? Data,
                      let decrypted = try? decrypt(payload, key: key)
                else { continue }

                switch kind {
                case "checkIn":
                    guard let dto = try? JSONDecoder().decode(CheckInDTO.self, from: decrypted),
                          !existingCheckInIDs.contains(dto.id) else { continue }
                    context.insert(dto.toModel())
                    restoredCount += 1
                case "smile":
                    guard let dto = try? JSONDecoder().decode(SmileDTO.self, from: decrypted),
                          !existingSmileIDs.contains(dto.id) else { continue }
                    context.insert(dto.toModel())
                    restoredCount += 1
                default:
                    continue
                }
            }
        }

        try context.save()
        return restoredCount
    }

    private func makeRecord<T: Encodable>(name: String, kind: String, payload: T, updatedAt: Date, key: SymmetricKey) throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: name))
        let data = try JSONEncoder().encode(payload)
        record["kind"] = kind
        record["payload"] = try encrypt(data, key: key)
        record["updatedAt"] = updatedAt
        return record
    }

    private func save(_ records: [CKRecord], to database: CKDatabase) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        guard let sealed = try AES.GCM.seal(data, using: key).combined else {
            throw BackupError.encryptionFailed
        }
        return sealed
    }

    private func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }
}
