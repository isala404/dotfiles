import Foundation
import Security
import LocalAuthentication
import Darwin

let args = CommandLine.arguments

guard args.count >= 2 else {
    fputs("Usage: keychain-bio <unlock|store|get> [service] [value]\n", stderr)
    exit(1)
}

let action = args[1]
let touchCacheFile = NSTemporaryDirectory() + "keychain-bio-touch-\(NSUserName())"
let unlockLockFile = NSTemporaryDirectory() + "keychain-bio-unlock-\(NSUserName())"

func touchCacheIdleTimeout() -> TimeInterval {
    let environment = ProcessInfo.processInfo.environment
    guard let value = environment["BWS_TOUCH_ID_IDLE_TIMEOUT_SECONDS"] else {
        return 300
    }
    guard let timeout = TimeInterval(value), timeout.isFinite, timeout > 0 else {
        fputs("BWS_TOUCH_ID_IDLE_TIMEOUT_SECONDS must be a positive number\n", stderr)
        exit(1)
    }
    return timeout
}

func updateTouchIDCache() {
    let fm = FileManager.default
    if fm.fileExists(atPath: touchCacheFile) {
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: touchCacheFile)
    } else {
        fm.createFile(atPath: touchCacheFile, contents: nil)
        chmod(touchCacheFile, 0o600)
    }
}

func touchIDCacheValid() -> Bool {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: touchCacheFile),
          let modified = attrs[.modificationDate] as? Date else {
        return false
    }
    guard Date().timeIntervalSince(modified) < touchCacheIdleTimeout() else {
        return false
    }
    return true
}

func authenticate(reason: String) {
    let context = LAContext()
    context.localizedReason = reason

    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        fputs("Authentication not available: \(error?.localizedDescription ?? "unknown")\n", stderr)
        exit(1)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var authSuccess = false

    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
        authSuccess = success
        if !success {
            fputs("Authentication failed: \(error?.localizedDescription ?? "unknown")\n", stderr)
        }
        semaphore.signal()
    }

    semaphore.wait()
    if !authSuccess { exit(1) }
}

func openUnlockLock() -> Int32 {
    let descriptor = open(unlockLockFile, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    guard descriptor != -1 else {
        fputs("Failed to open unlock lock: \(String(cString: strerror(errno)))\n", stderr)
        exit(1)
    }
    guard fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
        fputs("Failed to secure unlock lock: \(String(cString: strerror(errno)))\n", stderr)
        close(descriptor)
        exit(1)
    }
    return descriptor
}

func unlockActive() -> Bool {
    let descriptor = openUnlockLock()
    defer { close(descriptor) }

    if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
        flock(descriptor, LOCK_UN)
        return false
    }
    return errno == EWOULDBLOCK
}

enum AccessAuthorization {
    case unlockLease
    case touchIDCache
}

func authorizeAccess(service: String) -> AccessAuthorization {
    if unlockActive() { return .unlockLease }
    if touchIDCacheValid() { return .touchIDCache }

    authenticate(reason: "Access \(service)")
    updateTouchIDCache()
    return .touchIDCache
}

func unlock() -> Never {
    authenticate(reason: "Unlock keychain-bio")

    let descriptor = openUnlockLock()
    guard flock(descriptor, LOCK_SH) == 0 else {
        fputs("Failed to hold unlock lock: \(String(cString: strerror(errno)))\n", stderr)
        close(descriptor)
        exit(1)
    }

    fputs("Unlocked. Press Ctrl-C to lock.\n", stderr)
    while true {
        pause()
    }
}

func store(service: String, value: String) {
    let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: NSUserName(),
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: NSUserName(),
        kSecValueData as String: value.data(using: .utf8)!,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
        fputs("Failed to store: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)\n", stderr)
        exit(1)
    }
    print("Stored successfully")
}

func get(service: String) {
    let authorization = authorizeAccess(service: service)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: NSUserName(),
        kSecReturnData as String: true,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status != errSecSuccess {
        fputs("Failed to retrieve: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)\n", stderr)
        exit(1)
    }

    if case .touchIDCache = authorization {
        updateTouchIDCache()
    }

    if let data = result as? Data, let value = String(data: data, encoding: .utf8) {
        print(value.trimmingCharacters(in: .whitespacesAndNewlines), terminator: "")
    }
}

switch action {
case "unlock":
    guard args.count == 2 else {
        fputs("Usage: keychain-bio unlock\n", stderr)
        exit(1)
    }
    unlock()
case "store":
    guard args.count == 4 else {
        fputs("Usage: keychain-bio store <service> <value>\n", stderr)
        exit(1)
    }
    store(service: args[2], value: args[3])
case "get":
    guard args.count == 3 else {
        fputs("Usage: keychain-bio get <service>\n", stderr)
        exit(1)
    }
    get(service: args[2])
default:
    fputs("Unknown action: \(action)\n", stderr)
    exit(1)
}
