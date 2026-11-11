import AppKit

private func makeForm(weight: Double = 90, cup: Double = 350, hours: Double = 8, eyeMinutes: Double = 20) -> SettingsForm {
    SettingsForm(
        profile: HealthProfile(bodyWeightKg: weight, cupVolumeMl: cup, workHours: hours),
        timers: ReminderTimerSettings(eyeInterval: eyeMinutes * 60)
    )
}

@MainActor
private func stepper(_ controller: SettingsWindowController, _ field: SettingsForm.Field) throws -> PixelStepper {
    guard let stepper = controller.view.steppers[field] else {
        throw TestFailure(message: "settings window should have a stepper for \(field)")
    }
    return stepper
}

@MainActor
func testSettingsWindowStepsSavesImmediatelyAndShowsTheNewValue() throws {
    var saved: [SettingsForm] = []
    let controller = SettingsWindowController(form: makeForm(), decoration: nil) { saved.append($0) }

    let weight = try stepper(controller, .bodyWeight)
    try expect(weight.valueText == "90 kg", "the stepper should show the current weight (got \(weight.valueText))")
    weight.plusButton.performClick(nil)
    try expect(saved.last?.profile.bodyWeightKg == 91, "pressing + should save the new weight right away")
    try expect(weight.valueText == "91 kg", "the stepper should show the new weight (got \(weight.valueText))")

    let eye = try stepper(controller, .eyeInterval)
    eye.minusButton.performClick(nil)
    try expect(saved.last?.timers.eyeInterval == 15 * 60, "the eye interval arrows move between choices")
    try expect(saved.count == 2, "each press saves once (got \(saved.count))")
}

@MainActor
func testSettingsWindowDisablesButtonsAtTheEndsAndShowsSaveErrors() throws {
    struct SaveFailure: Error {}
    let controller = SettingsWindowController(form: makeForm(weight: 30), decoration: nil) { _ in throw SaveFailure() }

    let weight = try stepper(controller, .bodyWeight)
    try expect(!weight.minusButton.isEnabled, "minus should be disabled at the minimum weight")
    weight.minusButton.performClick(nil)
    try expect(controller.form.profile.bodyWeightKg == 30, "a disabled button should not change anything")

    weight.plusButton.performClick(nil)
    try expect(controller.view.message != nil, "a failed save should show a message in the window")
    try expect(controller.form.profile.bodyWeightKg == 31, "the form keeps the new value so the user can retry")
}

@MainActor
func testSettingsWindowCloseButtonClosesTheWindow() throws {
    let controller = SettingsWindowController(form: makeForm(), decoration: nil) { _ in }
    controller.present()
    try expect(controller.window?.isVisible == true, "present should show the window")
    controller.view.closeButton.performClick(nil)
    try expect(controller.window?.isVisible == false, "the close button should close the window")
}

@MainActor
func testSettingsWindowOffersRecommendedEyeModes() throws {
    var saved: [SettingsForm] = []
    let controller = SettingsWindowController(form: SettingsForm(profile: .default, timers: .default), decoration: nil) { saved.append($0) }

    guard let hourly = controller.view.modeButtons[.hourlyBreak], let recommended = controller.view.modeButtons[.rule202020] else {
        throw TestFailure(message: "settings should offer one button per eye care mode")
    }
    try expect(recommended.fillColor == PixelPalette.yellow, "the recommended mode is selected by default")
    let eyeStepper = try stepper(controller, .eyeInterval)
    try expect(!eyeStepper.plusButton.isEnabled, "preset modes lock the interval arrows")

    hourly.performClick(nil)
    try expect(saved.last?.timers.eyeMode == .hourlyBreak, "choosing a mode saves it right away")
    try expect(hourly.fillColor == PixelPalette.yellow && recommended.fillColor != PixelPalette.yellow, "the chosen mode is highlighted")
    try expect(controller.view.eyeModeExplanation.contains("5 分钟"), "the explanation follows the chosen mode")
}

@MainActor
func testSettingsWindowOffersTheLanguageSwitchAndRetitlesOnReload() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    TextCatalog.installShared(try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: .chinese))

    var chosen: [AppLanguage] = []
    let controller = SettingsWindowController(
        form: makeForm(),
        language: .chinese,
        decoration: nil,
        onSelectLanguage: { chosen.append($0) }
    ) { _ in }

    guard let chinese = controller.view.languageButtons[.chinese], let english = controller.view.languageButtons[.english] else {
        throw TestFailure(message: "settings should offer one button per language")
    }
    try expect(chinese.title == "中文" && english.title == "English", "language names read in the current language")
    try expect(chinese.fillColor == PixelPalette.yellow, "the current language is highlighted")
    try expect(!english.frame.isEmpty && controller.view.bounds.contains(english.frame), "the language buttons fit in the panel")

    english.performClick(nil)
    try expect(chosen == [.english], "picking English tells the caller to save it")
    try expect(controller.view.language == .english, "the view follows the chosen language")

    TextCatalog.installShared(try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: .english))
    controller.reloadCopy()
    try expect(chinese.title == "Chinese", "in English the Chinese option is spelled in English")
}
