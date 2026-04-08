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
    var hydrationReminder: String

    enum CodingKeys: String, CodingKey {
        case statusIdle = "status_idle"
        case statusWorking = "status_working"
        case statusFocus = "status_focus"
        case statusBreak = "status_break"
        case focusEndLight = "focus_end_light"
        case focusEndHeavy = "focus_end_heavy"
        case stopWorkMessage = "stop_work_message"
        case eyeReminder = "eye_reminder"
        case hydrationReminder = "hydration_reminder"
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
            hydrationReminder,
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
                "hydration_reminder": hydrationReminder,
            ]
        ]
    }

    func statusPreviewLines() -> [String] {
        [
            "待机：\(statusIdle)",
            "工作：\(statusWorking)",
            "专注：\(statusFocus)",
            "暂离：\(statusBreak)",
        ]
    }

    func followUpPreviewLines() -> [String] {
        [
            "轻提醒：\(focusEndLight)",
            "重提醒：\(focusEndHeavy)",
            "收工：\(stopWorkMessage)",
            "护眼：\(eyeReminder)",
            "喝水：\(hydrationReminder)",
        ]
    }

    func previewSummaryText() -> String {
        (statusPreviewLines() + followUpPreviewLines()).joined(separator: "\n")
    }

    func bubblePreviewText() -> String {
        focusEndLight
    }
}
