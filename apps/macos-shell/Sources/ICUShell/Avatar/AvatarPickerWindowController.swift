import AppKit

final class AvatarPickerWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let avatars: [AvatarSummary]
    private let onApply: (String) -> Void
    private let onClose: () -> Void

    private var selectedAvatarID: String?
    private var tableView = NSTableView()
    private var previewImageView = NSImageView()
    private var nameLabel = AvatarPanelTheme.makeTitleLabel("")
    private var detailLabel = AvatarPanelTheme.makeLabel("", color: AvatarPanelTheme.muted)
    private var didFinish = false

    init(
        avatars: [AvatarSummary],
        currentAvatarID: String?,
        onApply: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.avatars = avatars
        self.selectedAvatarID = currentAvatarID ?? avatars.first?.id
        self.onApply = onApply
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        AvatarPanelTheme.styleWindow(window)
        super.init(window: window)
        window.delegate = self

        buildUI()
        updateSelectedRow()
        updatePreview()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        avatars.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellID = NSUserInterfaceItemIdentifier("avatarPicker.cell")
        let cell = (tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView) ?? NSTableCellView()
        cell.identifier = cellID

        let label: NSTextField
        if let existing = cell.textField {
            label = existing
        } else {
            label = AvatarPanelTheme.makeLabel("")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        let avatar = avatars[row]
        label.stringValue = avatar.name
        label.font = AvatarPanelTheme.bodyFont
        label.textColor = AvatarPanelTheme.text
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard avatars.indices.contains(tableView.selectedRow) else {
            return
        }

        selectedAvatarID = avatars[tableView.selectedRow].id
        updatePreview()
    }

    func windowWillClose(_ notification: Notification) {
        if !didFinish {
            onClose()
        }
    }

    private func buildUI() {
        guard
            let window,
            let contentView = window.contentView
        else {
            return
        }

        AvatarPanelTheme.styleWindow(window)
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let panes = NSStackView(views: [buildListCard(), buildPreviewCard()])
        panes.orientation = .horizontal
        panes.spacing = 14
        panes.distribution = .fillEqually
        panes.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true

        root.addArrangedSubview(panes)
        root.addArrangedSubview(buildFooter())

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    private func buildListCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .regular
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("avatarPicker.nameColumn")))
        tableView.delegate = self
        tableView.dataSource = self

        let scrollView = NSScrollView()
        AvatarPanelTheme.styleScrollView(scrollView)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel("形象列表", color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
        ])

        return card
    }

    private func buildPreviewCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        previewImageView = NSImageView()
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.borderColor = AvatarPanelTheme.border.cgColor
        previewImageView.layer?.borderWidth = 1
        previewImageView.layer?.cornerRadius = 6

        nameLabel = AvatarPanelTheme.makeTitleLabel("")
        detailLabel = AvatarPanelTheme.makeLabel("", color: AvatarPanelTheme.muted)

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel("预览与说明", color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(previewImageView)
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(detailLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),
            previewImageView.heightAnchor.constraint(equalToConstant: 260),
        ])

        return card
    }

    private func buildFooter() -> NSView {
        let newAvatarButton = NSButton(title: "＋ 新建形象…", target: nil, action: nil)
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(handleCancel))
        let applyButton = NSButton(title: "应用", target: self, action: #selector(handleApply))
        AvatarPanelTheme.styleSecondaryButton(newAvatarButton)
        AvatarPanelTheme.styleSecondaryButton(cancelButton)
        AvatarPanelTheme.stylePrimaryButton(applyButton)
        newAvatarButton.widthAnchor.constraint(equalToConstant: 132).isActive = true
        cancelButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        applyButton.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let right = NSStackView(views: [cancelButton, applyButton])
        right.orientation = .horizontal
        right.spacing = 8

        let footer = NSStackView(views: [newAvatarButton, NSView(), right])
        footer.orientation = .horizontal
        footer.spacing = 10
        return footer
    }

    private func selectedAvatar() -> AvatarSummary? {
        guard let selectedAvatarID else {
            return avatars.first
        }

        return avatars.first(where: { $0.id == selectedAvatarID }) ?? avatars.first
    }

    private func updateSelectedRow() {
        guard
            let selectedAvatarID,
            let row = avatars.firstIndex(where: { $0.id == selectedAvatarID })
        else {
            if !avatars.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self.selectedAvatarID = avatars[0].id
            }
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    private func updatePreview() {
        guard let avatar = selectedAvatar() else {
            previewImageView.image = nil
            nameLabel.stringValue = "未选择形象"
            detailLabel.stringValue = ""
            return
        }

        previewImageView.image = NSImage(contentsOf: avatar.previewURL)
        nameLabel.stringValue = avatar.name
        detailLabel.stringValue = avatar.style.isEmpty ? "未标注风格" : "风格：\(avatar.style)"
    }

    @objc private func handleCancel() {
        didFinish = true
        onClose()
        close()
    }

    @objc private func handleApply() {
        guard let avatarID = selectedAvatar()?.id else {
            return
        }

        didFinish = true
        onApply(avatarID)
        close()
    }
}
