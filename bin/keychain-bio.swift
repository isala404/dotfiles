import Foundation
import Security
import LocalAuthentication

let args = CommandLine.arguments

guard args.count >= 3 else {
    fputs("Usage: keychain-bio <store|get> <service> [value]\n", stderr)
    exit(1)
}

let action = args[1]
let service = args[2]
let touchCacheFile = NSTemporaryDirectory() + "keychain-bio-touch-\(NSUserName())"
let touchCacheTTL: TimeInterval = 300

func touchIDCacheValid() -> Bool {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: touchCacheFile),
          let modified = attrs[.modificationDate] as? Date else {
        return false
    }
    return Date().timeIntervalSince(modified) < touchCacheTTL
}

func updateTouchIDCache() {
    FileManager.default.createFile(atPath: touchCacheFile, contents: nil)
    chmod(touchCacheFile, 0o600)
}

func requireTouchID() {
    if touchIDCacheValid() { return }

    let context = LAContext()
    context.localizedReason = "Access \(service)"

    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        fputs("Authentication not available: \(error?.localizedDescription ?? "unknown")\n", stderr)
        exit(1)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var authSuccess = false

    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Access \(service)") { success, error in
        authSuccess = success
        if !success {
            fputs("Authentication failed: \(error?.localizedDescription ?? "unknown")\n", stderr)
        }
        semaphore.signal()
    }

    semaphore.wait()
    if !authSuccess { exit(1) }
    updateTouchIDCache()
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
    requireTouchID()

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

    if let data = result as? Data, let value = String(data: data, encoding: .utf8) {
        print(value.trimmingCharacters(in: .whitespacesAndNewlines), terminator: "")
    }
}

switch action {
case "store":
    guard args.count == 4 else {
        fputs("Usage: keychain-bio store <service> <value>\n", stderr)
        exit(1)
    }
    store(service: service, value: args[3])
case "get":
    guard args.count == 3 else {
        fputs("Usage: keychain-bio get <service>\n", stderr)
        exit(1)
    }
    get(service: service)
default:
    fputs("Unknown action: \(action)\n", stderr)
    exit(1)
}
