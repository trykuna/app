// Services/CalendarSync/EventSignature.swift
import Foundation
import EventKit
import CryptoKit

struct EventSignature {
    static func make(
        title: String?,
        start: Date?,
        end: Date?,
        isAllDay: Bool,
        alarms: [EKAlarm]?,
        notes: String?
    ) -> String {
        let alarmOffsets = (alarms ?? [])
            .compactMap { $0.relativeOffset }
            .map { String($0) }
            .sorted()
            .joined(separator: ",")
        
        let parts = [
            title ?? "",
            start?.iso8601 ?? "",
            end?.iso8601 ?? "",
            isAllDay ? "A1" : "A0",
            alarmOffsets,
            (notes ?? "").trimmedWithoutSignature()
        ]
        
        return String(sha256(parts.joined(separator: "|")).prefix(16))
    }
    
    static func make(from event: EKEvent) -> String {
        return make(
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            alarms: event.alarms,
            notes: event.notes
        )
    }
    
    static func extractSignature(from notes: String?) -> String? {
        guard let notes = notes,
              let range = notes.range(of: SyncConst.signatureMarker) else {
            return nil
        }
        
        let signaturePart = String(notes[range.upperBound...])
        return signaturePart.trim()
    }
}

// MARK: - SHA256 Helper

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}
