// Services/NotificationsManager.swift
import Foundation
import UserNotifications
import os

@MainActor
final class NotificationsManager: ObservableObject {
    static let shared = NotificationsManager()
    private let center = UNUserNotificationCenter.current()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let status = await withCheckedContinuation { (cont: CheckedContinuation<UNAuthorizationStatus, Never>) in
            center.getNotificationSettings { settings in
                cont.resume(returning: settings.authorizationStatus)
            }
        }
        authorizationStatus = status
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            let granted: Bool = await withCheckedContinuation { cont in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
            await refreshAuthorizationStatus()
            return granted
        }
        return authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    func postImmediate(title: String, body: String, thread: String? = nil, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        if let thread { content.threadIdentifier = thread }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                Log.app.error("Notifications: Failed to schedule immediate notification: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
