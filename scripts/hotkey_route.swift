#!/usr/bin/env swift
// hotkey_route.swift - 剪贴板监测模式: 复制即路由
// v2 — 改用 NSPasteboard changeCount 轮询，绕过 Accessibility 权限问题
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

debug("=== HotkeyRoute v2 STARTED ===")

// ─── 配置 ────────────────────────────────────────
let logDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".workbuddy/logs")
let logFile = "route_history.json"
let maxLogEntries = 200

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
    let path = logDir.appendingPathComponent(logFile)
    
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
    if entries.count > maxLogEntries {
        entries = Array(entries.suffix(maxLogEntries))
    }
    
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
    debug("NOTIFY: \(title) - \(body.prefix(40))")
}

// ─── 启动 ─────────────────────────────────────────
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
    debug("AUTH: granted=\(granted) error=\(error?.localizedDescription ?? "nil")")
}

var lastChangeCount = NSPasteboard.general.changeCount
var lastProcessedContent = ""

debug("INIT: changeCount=\(lastChangeCount)")

Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    let pb = NSPasteboard.general
    let current = pb.changeCount
    
    guard current != lastChangeCount else { return }
    debug("CHANGE: \(lastChangeCount) -> \(current)")
    lastChangeCount = current
    
    // 等待一小段时间确保内容完整写入
    Thread.sleep(forTimeInterval: 0.05)
    
    guard let content = pb.string(forType: .string), !content.isEmpty else {
        debug("CONTENT: empty or nil")
        return
    }
    guard content != lastProcessedContent else {
        debug("CONTENT: same as last, skip")
        return
    }
    lastProcessedContent = content
    
    let (model, reason) = routeModel(content)
    let preview = String(content.prefix(60))
    debug("ROUTE: [\(model)] \(preview)")
    
    logRoute(model: model, reason: reason, preview: preview)
    sendNotification(title: "建议: \(model)", body: "\(reason)\n内容: \(preview)")
}

RunLoop.main.run()
