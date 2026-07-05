import CryptoKit
import Foundation
import LocalAuthentication

struct VMConfig {
    let id: String
    let name: String
    let bridgeDir: URL
    let secret: SymmetricKey
    let allowedUsers: Set<String>
}

func parseConfig(_ url: URL) throws -> [String: String] {
    let text = try String(contentsOf: url, encoding: .utf8)
    var values: [String: String] = [:]
    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix("#") || !line.contains("=") {
            continue
        }
        let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        values[key] = value
    }
    return values
}

func dataFromHex(_ hex: String) throws -> Data {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count % 2 == 0 else {
        throw NSError(domain: "ParallelsTouchIDHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid secret hex length"])
    }
    var data = Data()
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
        let next = cleaned.index(index, offsetBy: 2)
        guard let byte = UInt8(cleaned[index..<next], radix: 16) else {
            throw NSError(domain: "ParallelsTouchIDHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "invalid secret hex"])
        }
        data.append(byte)
        index = next
    }
    return data
}

func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

func hmacHex(key: SymmetricKey, message: String) -> String {
    let code = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
    return hex(Data(code))
}

func requestMessage(_ request: [String: String]) -> String {
    [
        "request-v1",
        request["id"] ?? "",
        request["user"] ?? "",
        request["service"] ?? "",
        request["tty"] ?? "",
        request["host"] ?? "",
        request["timestamp"] ?? "",
        request["nonce"] ?? "",
    ].joined(separator: "\n")
}

func responseMessage(_ response: [String: String]) -> String {
    [
        "response-v1",
        response["id"] ?? "",
        response["status"] ?? "",
        response["timestamp"] ?? "",
        response["request_hmac"] ?? "",
    ].joined(separator: "\n")
}

func writeJSON(_ object: [String: String], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let tmp = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".tmp")
    try data.write(to: tmp, options: .atomic)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: tmp, to: url)
}

func readJSON(_ url: URL) throws -> [String: String] {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
        throw NSError(domain: "ParallelsTouchIDHelper", code: 3, userInfo: [NSLocalizedDescriptionKey: "request is not a JSON object"])
    }
    var result: [String: String] = [:]
    for (key, value) in dictionary {
        result[key] = String(describing: value)
    }
    return result
}

func authenticate(reason: String) -> Bool {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        NSLog("ParallelsTouchIDHelper: Touch ID unavailable: \(String(describing: error))")
        return false
    }

    let semaphore = DispatchSemaphore(value: 0)
    var accepted = false
    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
        if let evalError {
            NSLog("ParallelsTouchIDHelper: authentication error: \(evalError)")
        }
        accepted = success
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 60)
    return accepted
}

func loadConfigFile(_ url: URL) throws -> VMConfig {
    let values = try parseConfig(url)
    guard let bridgeDir = values["BRIDGE_DIR"], let secretHex = values["SECRET_HEX"] else {
        throw NSError(domain: "ParallelsTouchIDHelper", code: 4, userInfo: [NSLocalizedDescriptionKey: "BRIDGE_DIR and SECRET_HEX are required in \(url.path)"])
    }
    let secretData = try dataFromHex(secretHex)
    let fallbackID = url.deletingPathExtension().lastPathComponent
    let id = values["VM_ID"] ?? fallbackID
    let name = values["VM_NAME"] ?? id
    let allowedUsers = Set((values["ALLOWED_USERS"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    return VMConfig(
        id: id,
        name: name,
        bridgeDir: URL(fileURLWithPath: bridgeDir, isDirectory: true),
        secret: SymmetricKey(data: secretData),
        allowedUsers: allowedUsers
    )
}

func configFiles(from root: URL) -> [URL] {
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), !isDir.boolValue {
        return [root]
    }
    guard let entries = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
        return []
    }
    return entries.filter { $0.pathExtension == "env" }.sorted { $0.path < $1.path }
}

func loadConfigs(from root: URL) -> [VMConfig] {
    var configs: [VMConfig] = []
    for file in configFiles(from: root) {
        do {
            configs.append(try loadConfigFile(file))
        } catch {
            NSLog("ParallelsTouchIDHelper: skipping config \(file.path): \(error)")
        }
    }
    return configs
}

func ensureBridgeDirs(_ config: VMConfig) {
    let fileManager = FileManager.default
    for subdir in ["requests", "responses", "processed", "state"] {
        try? fileManager.createDirectory(at: config.bridgeDir.appendingPathComponent(subdir, isDirectory: true), withIntermediateDirectories: true)
    }
}

func writeHeartbeat(_ config: VMConfig) {
    let heartbeatURL = config.bridgeDir.appendingPathComponent("state/heartbeat")
    let timestamp = String(Date().timeIntervalSince1970)
    try? timestamp.write(to: heartbeatURL, atomically: true, encoding: .utf8)
}

func processRequest(_ requestURL: URL, config: VMConfig) {
    do {
        let request = try readJSON(requestURL)
        guard request["version"] == "1",
              let requestID = request["id"],
              let user = request["user"],
              let service = request["service"],
              let host = request["host"],
              let requestHMAC = request["request_hmac"] else {
            throw NSError(domain: "ParallelsTouchIDHelper", code: 5, userInfo: [NSLocalizedDescriptionKey: "missing request fields"])
        }
        if !config.allowedUsers.isEmpty && !config.allowedUsers.contains(user) {
            NSLog("ParallelsTouchIDHelper: refusing vm=\(config.name) user=\(user)")
            return
        }
        let expected = hmacHex(key: config.secret, message: requestMessage(request))
        guard expected == requestHMAC else {
            NSLog("ParallelsTouchIDHelper: bad request hmac vm=\(config.name) id=\(requestID)")
            return
        }
        guard let requestTimestamp = Int(request["timestamp"] ?? ""), abs(Int(Date().timeIntervalSince1970) - requestTimestamp) <= 120 else {
            NSLog("ParallelsTouchIDHelper: stale request vm=\(config.name) id=\(requestID)")
            return
        }

        let reason = "Approve \(config.name) \(service) authentication for \(user) on \(host)."
        let status = authenticate(reason: reason) ? "ok" : "denied"
        var response: [String: String] = [
            "version": "1",
            "id": requestID,
            "status": status,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "request_hmac": requestHMAC,
        ]
        response["response_hmac"] = hmacHex(key: config.secret, message: responseMessage(response))

        let responsesDir = config.bridgeDir.appendingPathComponent("responses", isDirectory: true)
        let responseURL = responsesDir.appendingPathComponent(requestID + ".json")
        try writeJSON(response, to: responseURL)

        let processedDir = config.bridgeDir.appendingPathComponent("processed", isDirectory: true)
        let processedURL = processedDir.appendingPathComponent(requestURL.lastPathComponent)
        try? FileManager.default.removeItem(at: processedURL)
        try? FileManager.default.moveItem(at: requestURL, to: processedURL)
    } catch {
        NSLog("ParallelsTouchIDHelper: failed to process vm=\(config.name) request=\(requestURL.path): \(error)")
    }
}

let defaultConfigRoot = NSHomeDirectory() + "/Library/Application Support/ParallelsTouchIDPAM/config.d"
let configRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultConfigRoot)
try? FileManager.default.createDirectory(at: configRoot, withIntermediateDirectories: true)

NSLog("ParallelsTouchIDHelper: started, configRoot=\(configRoot.path)")

while true {
    let configs = loadConfigs(from: configRoot)
    if configs.isEmpty {
        NSLog("ParallelsTouchIDHelper: no VM configs found under \(configRoot.path)")
    }
    for config in configs {
        ensureBridgeDirs(config)
        writeHeartbeat(config)
        let requestsDir = config.bridgeDir.appendingPathComponent("requests", isDirectory: true)
        if let entries = try? FileManager.default.contentsOfDirectory(at: requestsDir, includingPropertiesForKeys: nil) {
            for requestURL in entries where requestURL.pathExtension == "json" {
                processRequest(requestURL, config: config)
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.5)
}
