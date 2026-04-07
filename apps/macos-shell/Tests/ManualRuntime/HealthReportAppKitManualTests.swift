import AppKit

func testReminderCardRendersCompleteSnoozeAndSkipActions() throws {
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")
    view.showReminderCard(payload)

    try expect(
        findButton(in: view, title: "已完成") != nil,
        "reminder card should render the complete action"
    )
    try expect(
        findButton(in: view, title: "稍后提醒") != nil,
        "reminder card should render the snooze action"
    )
    try expect(
        findButton(in: view, title: "跳过") != nil,
        "reminder card should render the skip action"
    )
}
