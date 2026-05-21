#!/usr/bin/env swift
// hotkey_route.swift - 剪贴板监测模式 v3
// 绕过 NSPasteboard 限制，改用 osascript 'the clipboard' 读内容
// 编译: swiftc -o ~/Applications/HotkeyRoute.app/Contents/MacOS/HotkeyRoute hotkey_route.swift -framework AppKit -framework UserNotifications

import AppKit
import UserNotifications

// ─── 调试日志 ─────────────────────────────────────
func debug(_ msg: String) {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".workbuddy/logs/hotkey_debug.log")
    let line = "[\(Date())] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if let fh = try? FileHandle(forWritingTo: path) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        } else {
            try? data.write(to: path)
        }
    }
}

// ─── 配置 ────────────────────────────────────────
let logDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".workbuddy/logs")

// ─── 通过 osascript 读剪贴板 ─────────────────────
func readClipboard() -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", "the clipboard"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    
    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let content = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        return content?.isEmpty == true ? nil : content
    } catch {
        debug("osa error: \(error.localizedDescription)")
        return nil
    }
}

// ─── 路由规则 ─────────────────────────────────────
let codeKeywords: [String] = ["代码", "写代码", "函数", "debug", "class ", "重构", "写脚本", "bug", "编程", "程序", "api", "接口", "sql", "json", "python", "javascript", "shell", "报错"]
let visionKeywords: [String] = ["看图", "截图", "图片", "图像", "识别", "识图", "这张"]
let analysisKeywords: [String] = ["分析", "对比", "深度", "推理", "复杂", "综合", "评估", "策略", "报告", "总结"]

func routeModel(_ msg: String) -> (model: String, reason: String) {
    let lower = msg.lowercased()
    if codeKeywords.contains(where: { lower.contains($0) }) {
        return ("Qwen3-Coder-30B", "编程/代码任务")
    }
    if visionKeywords.contains(where: { lower.contains($0) }) {
        return ("Qwen3-VL-32B", "图片/视觉任务")
    }
    if analysisKeywords.contains(where: { lower.contains($0) }) {
        return ("Qwen3.6-35B", "深度分析任务")
    }
    return ("DeepSeek-V4-Flash", "通用任务")
}

// ─── 日志 ─────────────────────────────────────────
func logRoute(model: String, reason: String, preview: String) {
    try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
    let path = logDir.appendingPathComponent("route_history.json")
    
    var entries: [[String: String]] = []
    if let data = try? Data(contentsOf: path),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
        entries = existing
    }
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let entry: [String: String] = [
        "timestamp": formatter.string(from: Date()),
        "model": model,
        "reason": reason,
        "preview": preview
    ]
    entries.append(entry)
    if entries.count > 200 { entries = Array(entries.suffix(200)) }
    
    if let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted]) {
        try? data.write(to: path)
    }
    debug("LOGGED: \(model) - \(reason)")
}

// ─── 通知 ─────────────────────────────────────────
func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
        if let e = error { debug("NOTIFY ERROR: \(e.localizedDescription)") }
    }
    debug("NOTIFY: \(title)")
}

// ─── 启动 ─────────────────────────────────────────
debug("=== HotkeyRoute v3 STARTED ===")

// 先重置通知权限标识，重新请求
// 通过删除旧的 UNUserNotificationCenter 委托来确保新请求
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    debug("AUTH: granted=\(granted) error=\(error?.localizedDescription ?? "nil")")
}

var lastContent = ""
var lastChangeCount = NSPasteboard.general.changeCount
var unchangedCycles = 0  // 防抖

debug("INIT: changeCount=\(lastChangeCount)")

Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
    let pb = NSPasteboard.general
    let current = pb.changeCount
    
    guard current != lastChangeCount else { return }
    lastChangeCount = current
    debug("CHANGE: \(current)")
    
    // 延时后通过 osascript 读取内容
    Thread.sleep(forTimeInterval: 0.2)
    
    guard let content = readClipboard(), !content.isEmpty else {
        debug("osa CONTENT: nil/empty")
        return
    }
    
    // 防抖：内容没变可能是连续复制同一东西
    guard content != lastContent else {
        debug("CONTENT: duplicate, skip")
        return
    }
    lastContent = content
    unchangedCycles = 0
    
    let (model, reason) = routeModel(content)
    let preview = String(content.prefix(60))
    debug("ROUTE: [\(model)] \(preview)")
    
    logRoute(model: model, reason: reason, preview: preview)
    sendNotification(title: "建议: \(model)", body: "\(reason)\n内容: \(preview)")
}

RunLoop.main.run()
