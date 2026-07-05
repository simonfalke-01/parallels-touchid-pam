import CryptoKit
import Foundation
import LocalAuthentication

struct Config {
    let bridgeDir: URL
    let secret: SymmetricKey
    let allowedUsers: Set<String>
    let pollInterval: TimeInterval
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
        throw NSError(domain: "FedoraTouchIDHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid secret hex length"])
    }
    var data = Data()
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
        let next = cleaned.index(index, offsetBy: 2)
        guard let byte = UInt8(cleaned[index..<next], radix: 16) else {
            throw NSError(domain: "FedoraTouchIDHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "invalid secret hex"])
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
        throw NSError(domain: "FedoraTouchIDHelper", code: 3, userInfo: [NSLocalizedDescriptionKey: "request is not a JSON object"])
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
        NSLog("FedoraTouchIDHelper: Touch ID unavailable: \(String(describing: error))")
        return false
    }

    let semaphore = DispatchSemaphore(value: 0)
    var accepted = false
    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
        if let evalError {
            NSLog("FedoraTouchIDHelper: authentication error: \(evalError)")
        }
        accepted = success
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 60)
    return accepted
}

func processRequest(_ requestURL: URL, config: Config) {
    do {
        let request = try readJSON(requestURL)
        guard request["version"] == "1",
              let requestID = request["id"],
              let user = request["user"],
              let service = request["service"],
              let host = request["host"],
              let requestHMAC = request["request_hmac"] else {
            throw NSError(domain: "FedoraTouchIDHelper", code: 4, userInfo: [NSLocalizedDescriptionKey: "missing request fields"])
        }
        if !config.allowedUsers.isEmpty && !config.allowedUsers.contains(user) {
            NSLog("FedoraTouchIDHelper: refusing user \(user)")
            return
        }
        let expected = hmacHex(key: config.secret, message: requestMessage(request))
        guard expected == requestHMAC else {
            NSLog("FedoraTouchIDHelper: bad request hmac for \(requestID)")
            return
        }
        guard let requestTimestamp = Int(request["timestamp"] ?? ""), abs(Int(Date().timeIntervalSince1970) - requestTimestamp) <= 120 else {
            NSLog("FedoraTouchIDHelper: stale request \(requestID)")
            return
        }

        let reason = "Approve Fedora \(service) authentication for \(user) on \(host)."
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
        NSLog("FedoraTouchIDHelper: failed to process \(requestURL.path): \(error)")
    }
}

func loadConfig() throws -> Config {
    let configPath: String
    if CommandLine.arguments.count > 1 {
        configPath = CommandLine.arguments[1]
    } else {
        configPath = NSHomeDirectory() + "/Library/Application Support/FedoraTouchIDPAM/config.env"
    }
    let values = try parseConfig(URL(fileURLWithPath: configPath))
    guard let bridgeDir = values["BRIDGE_DIR"], let secretHex = values["SECRET_HEX"] else {
        throw NSError(domain: "FedoraTouchIDHelper", code: 5, userInfo: [NSLocalizedDescriptionKey: "BRIDGE_DIR and SECRET_HEX are required"])
    }
    let secretData = try dataFromHex(secretHex)
    let allowedUsers = Set((values["ALLOWED_USERS"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    let pollInterval = TimeInterval(values["POLL_INTERVAL_SECONDS"] ?? "0.5") ?? 0.5
    return Config(
        bridgeDir: URL(fileURLWithPath: bridgeDir, isDirectory: true),
        secret: SymmetricKey(data: secretData),
        allowedUsers: allowedUsers,
        pollInterval: pollInterval
    )
}

let config = try loadConfig()
let fileManager = FileManager.default
try fileManager.createDirectory(at: config.bridgeDir.appendingPathComponent("requests", isDirectory: true), withIntermediateDirectories: true)
try fileManager.createDirectory(at: config.bridgeDir.appendingPathComponent("responses", isDirectory: true), withIntermediateDirectories: true)
try fileManager.createDirectory(at: config.bridgeDir.appendingPathComponent("processed", isDirectory: true), withIntermediateDirectories: true)
try fileManager.createDirectory(at: config.bridgeDir.appendingPathComponent("state", isDirectory: true), withIntermediateDirectories: true)

let heartbeatURL = config.bridgeDir.appendingPathComponent("state/heartbeat")
NSLog("FedoraTouchIDHelper: started, bridge=\(config.bridgeDir.path)")

while true {
    let timestamp = String(Date().timeIntervalSince1970)
    try? timestamp.write(to: heartbeatURL, atomically: true, encoding: .utf8)

    let requestsDir = config.bridgeDir.appendingPathComponent("requests", isDirectory: true)
    if let entries = try? fileManager.contentsOfDirectory(at: requestsDir, includingPropertiesForKeys: nil) {
        for requestURL in entries where requestURL.pathExtension == "json" {
            processRequest(requestURL, config: config)
        }
    }
    Thread.sleep(forTimeInterval: config.pollInterval)
}
