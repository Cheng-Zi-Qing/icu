import Foundation

func testHydrationPlanFollowsBodyWeightFormula() throws {
    // 70kg：每天 2450ml，工作时段喝 65% ≈ 1592ml，300ml 的杯子要 6 杯，8 小时里每 80 分钟一杯
    let plan = HydrationPlan(profile: HealthProfile(bodyWeightKg: 70, cupVolumeMl: 300, workHours: 8))
    try expect(plan.dailyWaterMl == 2450, "daily water should be weight × 35ml (got \(plan.dailyWaterMl))")
    try expect(abs(plan.workWaterMl - 1592.5) < 0.001, "work water should be 65% of daily (got \(plan.workWaterMl))")
    try expect(plan.cups == 6, "cups should round up (got \(plan.cups))")
    try expect(plan.interval == 80 * 60, "interval should spread cups over work hours (got \(plan.interval))")
}

func testHydrationPlanRoundsCupsUpAndShrinksIntervalForSmallCups() throws {
    let big = HydrationPlan(profile: HealthProfile(bodyWeightKg: 90, cupVolumeMl: 350, workHours: 8))
    try expect(big.cups == 6, "2047.5ml in 350ml cups needs 6 cups (got \(big.cups))")

    let small = HydrationPlan(profile: HealthProfile(bodyWeightKg: 90, cupVolumeMl: 150, workHours: 8))
    try expect(small.cups == 14, "2047.5ml in 150ml cups needs 14 cups (got \(small.cups))")
    try expect(small.interval < big.interval, "smaller cups should remind more often")
}

func testHealthProfileParsesUserSectionAndFallsBackPerField() throws {
    let parsed = HealthProfile(settingsObject: ["user": ["body_weight": 90, "cup_volume": 350, "work_hours": 7.5]])
    try expect(
        parsed == HealthProfile(bodyWeightKg: 90, cupVolumeMl: 350, workHours: 7.5),
        "profile should come from the user section (got \(parsed))"
    )

    try expect(HealthProfile(settingsObject: nil) == .default, "missing config should use defaults")

    let invalid = HealthProfile(settingsObject: ["user": ["body_weight": -3, "cup_volume": "big", "work_hours": true]])
    try expect(invalid == .default, "out-of-range, non-numeric and boolean values should fall back (got \(invalid))")
}

func testReminderTimerSettingsParseEyeIntervalInSeconds() throws {
    let parsed = ReminderTimerSettings(settingsObject: ["timers": ["eye_interval": 1500]])
    try expect(parsed.eyeInterval == 1500, "eye interval is stored in seconds (got \(parsed.eyeInterval))")

    try expect(ReminderTimerSettings(settingsObject: nil) == .default, "missing config should use defaults")
    try expect(ReminderTimerSettings.default.eyeInterval == 20 * 60, "default eye interval follows the 20-20-20 rule")

    let tooShort = ReminderTimerSettings(settingsObject: ["timers": ["eye_interval": 5]])
    try expect(tooShort == .default, "an eye interval shorter than a minute should fall back")
}

func testAppSettingsStoreLoadsHealthProfileAndTimers() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configDir = root.appendingPathComponent("config", isDirectory: true)
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = AppSettingsStore(repoRootURL: root)
    try expect(store.loadHealthProfile() == .default, "missing settings file should give the default profile")
    try expect(store.loadReminderTimerSettings() == .default, "missing settings file should give default timers")

    let json = #"{"user": {"body_weight": 55, "cup_volume": 250, "work_hours": 6}, "timers": {"eye_interval": 900}}"#
    try json.data(using: .utf8)!.write(to: configDir.appendingPathComponent("settings.json"))
    try expect(
        store.loadHealthProfile() == HealthProfile(bodyWeightKg: 55, cupVolumeMl: 250, workHours: 6),
        "profile should be read from settings.json"
    )
    try expect(store.loadReminderTimerSettings().eyeInterval == 900, "eye interval should be read from settings.json")
}

func testEyeCareModesFollowPublishedRecommendations() throws {
    let rule = ReminderTimerSettings.default
    try expect(rule.eyeMode == .rule202020, "the recommended default is the 20-20-20 rule")
    try expect(rule.eyeInterval == 20 * 60 && rule.eyeRestSeconds == 20, "20-20-20: every 20 minutes, look away for 20 seconds")

    let hourly = ReminderTimerSettings(eyeMode: .hourlyBreak)
    try expect(hourly.eyeInterval == 60 * 60 && hourly.eyeRestSeconds == 5 * 60, "NIOSH supplementary breaks: 5 minutes every hour")

    let custom = ReminderTimerSettings(eyeMode: .custom, customEyeInterval: 30 * 60)
    try expect(custom.eyeInterval == 30 * 60 && custom.eyeRestSeconds == 20, "custom keeps the user's interval and a 20 second look-away")
}

func testReminderTimerSettingsParseEyeModeAndKeepOldConfigsWorking() throws {
    let hourly = ReminderTimerSettings(settingsObject: ["timers": ["eye_mode": "hourly_break", "eye_interval": 1500]])
    try expect(hourly.eyeMode == .hourlyBreak && hourly.eyeInterval == 3600, "a preset mode ignores the stored custom interval")
    try expect(hourly.customEyeInterval == 1500, "the custom interval is remembered for later")

    let legacyCustom = ReminderTimerSettings(settingsObject: ["timers": ["eye_interval": 1500]])
    try expect(legacyCustom.eyeMode == .custom, "an old config with a non-default interval becomes custom")

    let legacyDefault = ReminderTimerSettings(settingsObject: ["timers": ["eye_interval": 1200]])
    try expect(legacyDefault == .default, "an old config with 20 minutes is the recommended mode")

    let unknown = ReminderTimerSettings(settingsObject: ["timers": ["eye_mode": "pomodoro"]])
    try expect(unknown == .default, "an unknown mode falls back to the recommended one")
}
