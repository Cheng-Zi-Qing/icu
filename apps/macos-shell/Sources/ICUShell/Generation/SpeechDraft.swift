import Foundation

struct SpeechDraft: Codable, Equatable {
    var statusIdle: String
    var statusWorking: String
    var statusFocus: String
    var statusBreak: String
    var focusEndLight: String
    var focusEndHeavy: String
    var stopWorkMessage: String
    var eyeReminder: String

    enum CodingKeys: String, CodingKey {
        case statusIdle = "status_idle"
        case statusWorking = "status_working"
        case statusFocus = "status_focus"
        case statusBreak = "status_break"
        case focusEndLight = "focus_end_light"
        case focusEndHeavy = "focus_end_heavy"
        case stopWorkMessage = "stop_work_message"
        case eyeReminder = "eye_reminder"
    }

    func validate() throws {
        let requiredValues = [
            statusIdle,
            statusWorking,
            statusFocus,
            statusBreak,
            focusEndLight,
            focusEndHeavy,
            stopWorkMessage,
            eyeReminder,
        ]

        guard requiredValues.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw GenerationRouteError.invalidResponse("speech draft contains empty required fields")
        }
    }

    func overrideRootObject() -> [String: Any] {
        [
            "pet": [
                "status_idle": statusIdle,
                "status_working": statusWorking,
                "status_focus": statusFocus,
                "status_break": statusBreak,
                "focus_end_light": focusEndLight,
                "focus_end_heavy": focusEndHeavy,
                "stop_work_message": stopWorkMessage,
                "eye_reminder": eyeReminder,
            ]
        ]
    }

    func previewSummaryText() -> String {
        [
            "待机：\(statusIdle)",
            "收工：\(stopWorkMessage)",
            "提醒：\(eyeReminder)",
        ].joined(separator: "\n")
    }

    func bubblePreviewText() -> String {
        focusEndLight
    }
}
