import AppKit

func findTextField(in root: NSView, placeholder: String) -> NSTextField? {
    allSubviews(in: root)
        .compactMap { $0 as? NSTextField }
        .first { $0.placeholderString == placeholder }
}

func requireTextField(in root: NSView, placeholder: String) throws -> NSTextField {
    if let field = findTextField(in: root, placeholder: placeholder) {
        return field
    }

    throw TestFailure(message: "expected text field with placeholder '\(placeholder)' to exist")
}

func findButton(in root: NSView, title: String) -> NSButton? {
    allSubviews(in: root).compactMap { $0 as? NSButton }.first { $0.title == title }
}

func findLabel(in root: NSView, stringValue: String) -> NSTextField? {
    allSubviews(in: root).compactMap { $0 as? NSTextField }.first { $0.stringValue == stringValue }
}

func requirePixelButton(in root: NSView, title: String) throws -> PixelButton {
    guard let button = allSubviews(in: root).compactMap({ $0 as? PixelButton }).first(where: { $0.title == title }) else {
        throw TestFailure(message: "expected a pixel button titled \(title)")
    }
    return button
}
