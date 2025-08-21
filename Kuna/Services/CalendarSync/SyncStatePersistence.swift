import Foundation

final class SyncStatePersistence {
    private let userDefaults = UserDefaults.standard
    private let keychain = KeychainHelper()

    // Keys
    private let syncStateKey = "CalendarSyncState"
    private let idMapKey = "CalendarIdMap"
    private let projectCalMapKey = "CalendarProjectMap"
    private let perProjectEnabledKey = "calendarSyncPerProjectEnabled"
    private let enabledListsKey = "calendarSyncEnabledLists"

    // MARK: - Sync State Persistence

    func loadSyncState() -> CalendarSyncState {
        guard let data = userDefaults.data(forKey: syncStateKey),
              let state = try? JSONDecoder().decode(CalendarSyncState.self, from: data) else {
            return CalendarSyncState()
        }
        return state
    }

    func saveSyncState(_ state: CalendarSyncState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: syncStateKey)
        } catch {
            Log.app.error("Failed to save sync state: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - ID Map Persistence

    func loadIdMap() -> IdMap {
        guard let data = userDefaults.data(forKey: idMapKey),
              let idMap = try? JSONDecoder().decode(IdMap.self, from: data) else {
            return IdMap()
        }
        return idMap
    }

    func saveIdMap(_ idMap: IdMap) {
        do {
            let data = try JSONEncoder().encode(idMap)
            userDefaults.set(data, forKey: idMapKey)
        } catch {
            Log.app.error("Failed to save ID map: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Project Calendar Map

    func loadProjectCalendarMap() -> ProjectCalendarMap {
        guard let data = userDefaults.data(forKey: projectCalMapKey),
              let map = try? JSONDecoder().decode(ProjectCalendarMap.self, from: data) else {
            return ProjectCalendarMap()
        }
        return map
    }

    func saveProjectCalendarMap(_ map: ProjectCalendarMap) {
        if let data = try? JSONEncoder().encode(map) {
            userDefaults.set(data, forKey: projectCalMapKey)
        }
    }

    // MARK: - Per-Project Toggle + Enabled Lists

    func loadPerProjectEnabled() -> Bool {
        userDefaults.bool(forKey: perProjectEnabledKey)
    }
    func savePerProjectEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: perProjectEnabledKey)
    }

    func loadEnabledListIDs() -> [String] {
        userDefaults.stringArray(forKey: enabledListsKey) ?? []
    }
    func saveEnabledListIDs(_ ids: [String]) {
        userDefaults.set(ids, forKey: enabledListsKey)
    }

    // MARK: - Clear All Data

    func clearAllData() {
        userDefaults.removeObject(forKey: syncStateKey)
        userDefaults.removeObject(forKey: idMapKey)
        userDefaults.removeObject(forKey: projectCalMapKey)
    }
}

// MARK: - Keychain Helper

private class KeychainHelper {
    func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
