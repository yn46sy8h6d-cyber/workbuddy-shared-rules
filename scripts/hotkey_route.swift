#!/usr/bin/env swift
// hotkey_route.swift - 全局快捷键: Option+M 触发模型路由建议
// 编译: swiftc -o ~/Applications/HotkeyRoute hotkey_route.swift -framework Carbon -framework AppKit -framework UserNotifications

import Carbon
import AppKit
import UserNotifications

var eventHandlerRef: EventHandlerRef?

// 日志路径
let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".workbuddy/logs")
let logFile = "route_history.json"
let maxLogEntries = 200

func logRoute(model: String, reason: String, preview: String) {
    let fm = FileManager.default
    // 确保日志目录存在
    try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
    
    let logPath = logDir.appendingPathComponent(logFile)
    
    var entries: [[String: String]] = []
    
    // 读取已有日志
    if let data = try? Data(contentsOf: logPath),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
        entries = existing
    }
    
    // 添加新条目
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let entry: [String: String] = [
        "timestamp": formatter.string(from: Date()),
        "model": model,
        "reason": reason,
        "preview": preview
    ]
    entries.append(entry)
    
    // 限制条目数
    if entries.count > maxLogEntries {
        entries = Array(entries.suffix(maxLogEntries))
    }
    
    // 写回
    if let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted]) {
        try? data.write(to: logPath)
    }
}

func hotKeyHandler(_: EventHandlerCallRef?, _: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    let pasteboard = NSPasteboard.general
    guard let msg = pasteboard.string(forType: .string), !msg.isEmpty else {
        sendNotification(title: "模型路由", body: "剪贴板为空，请先复制消息内容")
        return noErr
    }
    
    let lowerMsg = msg.lowercased()
    let codeKeywords: [String] = ["代码", "写代码", "函数", "debug", "class ", "重构", "写脚本", "bug", "编程", "程序", "api", "接口", "sql", "json", "python", "javascript", "shell", "报错"]
    let visionKeywords: [String] = ["看图", "截图", "图片", "图像", "识别", "识图", "这张"]
    let analysisKeywords: [String] = ["分析", "对比", "深度", "推理", "复杂", "综合", "评估", "策略", "报告", "总结"]
    
    let model: String
    let reason: String
    
    if codeKeywords.contains(where: { lowerMsg.contains($0) }) {
        model = "Qwen3-Coder-30B"
        reason = "编程/代码任务"
    } else if visionKeywords.contains(where: { lowerMsg.contains($0) }) {
        model = "Qwen3-VL-32B"
        reason = "图片/视觉任务"
    } else if analysisKeywords.contains(where: { lowerMsg.contains($0) }) {
        model = "Qwen3.6-35B"
        reason = "深度分析任务"
    } else {
        model = "DeepSeek-V4-Flash"
        reason = "通用任务"
    }
    
    let preview = String(msg.prefix(60))
    
    // 记录日志
    logRoute(model: model, reason: reason, preview: preview)
    
    // 发送通知
    sendNotification(title: "建议: \(model)", body: "\(reason)\n内容: \(preview)")
    return noErr
}

func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { _ in }
}

// 注册全局热键: Option+M (keyCode 46, modifiers: optionKey)
var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
let hotKeyID = EventHotKeyID(signature: OSType(0x4D52545F), id: 1)
var hotKey: EventHotKeyRef?

InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, &eventHandlerRef)
RegisterEventHotKey(46, UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKey)

// 请求通知权限
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

print("ModelRoute 热键已启动: Option+M")
print("按 Ctrl+C 退出")
RunLoop.main.run()
