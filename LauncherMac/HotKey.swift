import Carbon.HIToolbox

final class HotKey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handler: EventHandlerRef?

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void
    private let id: UInt32
    private var reference: EventHotKeyRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
        self.id = HotKey.nextID
        HotKey.nextID += 1
    }

    deinit {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        HotKey.actions.removeValue(forKey: id)
    }

    func register() -> Bool {
        HotKey.installHandlerIfNeeded()
        guard HotKey.handler != nil else { return false }

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C4E_4348), id: id) // 'LNCH'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return false }

        self.reference = reference
        HotKey.actions[id] = action
        return true
    }

    func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
            self.reference = nil
        }
        HotKey.actions.removeValue(forKey: id)
    }

    private static func installHandlerIfNeeded() {
        guard handler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID(signature: 0, id: 0)
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            HotKey.actions[hotKeyID.id]?()
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &handler)
    }
}
