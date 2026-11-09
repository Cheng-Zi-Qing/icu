import Foundation

private let sampleForm = SettingsForm(
    profile: HealthProfile(bodyWeightKg: 90, cupVolumeMl: 350, workHours: 8),
    timers: ReminderTimerSettings(eyeInterval: 20 * 60)
)

func testSettingsFormStepsEachFieldWithoutChangingTheOriginal() throws {
    let heavier = sampleForm.stepped(.bodyWeight, by: 1)
    try expect(heavier.profile.bodyWeightKg == 91, "weight steps by 1kg (got \(heavier.profile.bodyWeightKg))")
    try expect(sampleForm.profile.bodyWeightKg == 90, "stepping must not change the original form")

    try expect(sampleForm.stepped(.cupVolume, by: -1).profile.cupVolumeMl == 300, "cup volume steps by 50ml")
    try expect(sampleForm.stepped(.workHours, by: 1).profile.workHours == 9, "work hours step by 1 hour")
    try expect(sampleForm.stepped(.eyeInterval, by: 1).timers.eyeInterval == 25 * 60, "eye interval moves to the next choice")
    try expect(sampleForm.stepped(.eyeInterval, by: -1).timers.eyeInterval == 15 * 60, "eye interval moves to the previous choice")
}

func testSettingsFormClampsAtTheEnds() throws {
    let light = SettingsForm(profile: HealthProfile(bodyWeightKg: 30, cupVolumeMl: 100, workHours: 1), timers: ReminderTimerSettings(eyeInterval: 10 * 60))
    try expect(light.stepped(.bodyWeight, by: -1) == light, "weight should not go below the minimum")
    try expect(light.stepped(.cupVolume, by: -1) == light, "cup volume should not go below the minimum")
    try expect(light.stepped(.workHours, by: -1) == light, "work hours should not go below the minimum")
    try expect(light.stepped(.eyeInterval, by: -1) == light, "eye interval should not go below the shortest choice")
    try expect(!light.canStep(.bodyWeight, by: -1), "the minus button should be disabled at the minimum")
    try expect(light.canStep(.bodyWeight, by: 1), "the plus button stays enabled")
}

func testSettingsFormSnapsAnOddEyeIntervalToTheNearestChoice() throws {
    let odd = SettingsForm(profile: .default, timers: ReminderTimerSettings(eyeInterval: 22 * 60))
    try expect(odd.stepped(.eyeInterval, by: 1).timers.eyeInterval == 25 * 60, "22 minutes steps up to 25")
    try expect(odd.stepped(.eyeInterval, by: -1).timers.eyeInterval == 20 * 60, "22 minutes steps down to 20")
}

func testSettingsFormShowsValuesAndHydrationSummary() throws {
    try expect(sampleForm.valueText(.bodyWeight) == "90 kg", "weight text (got \(sampleForm.valueText(.bodyWeight)))")
    try expect(sampleForm.valueText(.cupVolume) == "350 ml", "cup text")
    try expect(sampleForm.valueText(.workHours) == "8 小时", "work hours text")
    try expect(sampleForm.valueText(.eyeInterval) == "20 分钟", "eye interval text")
    try expect(sampleForm.cups == 6, "the summary shows one cup icon per suggested cup")
    try expect(
        sampleForm.hydrationHeadline == "建议上班时喝 6 杯（约 2050 ml）",
        "the headline says how much to drink at work, rounded to 10ml (got \(sampleForm.hydrationHeadline))"
    )
    try expect(
        sampleForm.hydrationDetail == "每 80 分钟提醒一次",
        "the detail says how often the reminder comes (got \(sampleForm.hydrationDetail))"
    )
}

func testAppSettingsStoreSavesProfileAndTimersWithoutDroppingOtherKeys() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configDir = root.appendingPathComponent("config", isDirectory: true)
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let json = #"{"edge_snap": {"enabled": false}, "timers": {"eye_interval": 1200, "stretch_interval": 2700}}"#
    try json.data(using: .utf8)!.write(to: configDir.appendingPathComponent("settings.json"))

    let store = AppSettingsStore(repoRootURL: root)
    try store.saveHealthProfile(HealthProfile(bodyWeightKg: 60, cupVolumeMl: 250, workHours: 7))
    try store.saveReminderTimerSettings(ReminderTimerSettings(eyeInterval: 30 * 60))

    try expect(store.loadHealthProfile() == HealthProfile(bodyWeightKg: 60, cupVolumeMl: 250, workHours: 7), "profile round-trips")
    try expect(store.loadReminderTimerSettings().eyeInterval == 30 * 60, "eye interval round-trips")
    let root2 = try store.loadRootObject()
    try expect((root2["timers"] as? [String: Any])?["stretch_interval"] as? Int == 2700, "other timer keys are kept")
    try expect(store.loadEdgeSnapSettings().isEnabled == false, "other sections are kept")
}

func testMenuTodaySummaryShowsCupsEyeBreaksAndWorkTime() throws {
    var day = HealthDaySummary(
        date: Date(), eyeReminder: .empty, hydrationReminder: .empty,
        workDuration: 3 * 3600 + 20 * 60 + 59, focusCount: 0, focusDuration: 0, breakCount: 0
    )
    day.hydrationReminder.completed = 3
    day.eyeReminder.completed = 5
    let summary = MenuTodaySummary(day: day, cupsGoal: 6)
    try expect(summary.cupsText == "3/6 杯", "cups text (got \(summary.cupsText))")
    try expect(summary.eyeText == "5 次", "eye text (got \(summary.eyeText))")
    try expect(summary.workText == "3:20", "work time is shown as h:mm (got \(summary.workText))")
}

func testSettingsFormSwitchesEyeModesAndOnlyStepsInCustom() throws {
    let recommended = SettingsForm(profile: .default, timers: .default)
    try expect(!recommended.canStep(.eyeInterval, by: 1), "a preset mode locks the interval arrows")
    try expect(recommended.valueText(.eyeInterval) == "20 分钟", "the locked row still shows the preset interval")

    let hourly = recommended.with(eyeMode: .hourlyBreak)
    try expect(hourly.timers.eyeMode == .hourlyBreak, "switching mode returns a new form")
    try expect(recommended.timers.eyeMode == .rule202020, "switching must not change the original form")
    try expect(hourly.valueText(.eyeInterval) == "60 分钟", "hourly mode shows 60 minutes")

    let custom = hourly.with(eyeMode: .custom)
    try expect(custom.timers.eyeInterval == 60 * 60, "custom starts from the interval the user was just using")
    try expect(custom.canStep(.eyeInterval, by: -1), "custom unlocks the arrows")
    try expect(custom.stepped(.eyeInterval, by: -1).timers.eyeInterval == 45 * 60, "and steps through the choices")
}

func testAppSettingsStoreSavesEyeMode() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("config", isDirectory: true), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = AppSettingsStore(repoRootURL: root)
    try store.saveReminderTimerSettings(ReminderTimerSettings(eyeMode: .hourlyBreak, customEyeInterval: 25 * 60))
    let loaded = store.loadReminderTimerSettings()
    try expect(loaded.eyeMode == .hourlyBreak && loaded.customEyeInterval == 25 * 60, "mode and custom interval round-trip (got \(loaded))")
}
