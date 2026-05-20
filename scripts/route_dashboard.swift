#!/usr/bin/env swift
// route_dashboard.swift - 全局 Dashboard
// 编译: swiftc -o ~/Applications/RouteDashboard route_dashboard.swift -framework AppKit

import AppKit

// ─── 数据模型 ───────────────────────────────────────
struct RouteEntry: Codable {
    let timestamp: String
    let model: String
    let reason: String
    let preview: String
}

let logPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".workbuddy/logs/route_history.json")

func loadHistory() -> [RouteEntry] {
    guard let data = try? Data(contentsOf: logPath),
          let entries = try? JSONDecoder().decode([RouteEntry].self, from: data) else {
        return []
    }
    return Array(entries.suffix(20))
}

// ─── 规则配置 ───────────────────────────────────────
struct RouteRule {
    let model: String
    let icon: String
    let keywords: [String]
    let desc: String
}

let rules: [RouteRule] = [
    RouteRule(model: "DeepSeek-V4-Flash",  icon: "⚡", keywords: ["默认通用"], desc: "通用任务、日常对话"),
    RouteRule(model: "Qwen3-Coder-30B",    icon: "🛠", keywords: ["代码、debug、API、SQL、JSON"], desc: "编程/代码/调试任务"),
    RouteRule(model: "Qwen3.6-35B",        icon: "🧠", keywords: ["分析、推理、评估、策略"], desc: "深度分析/复杂推理"),
    RouteRule(model: "Qwen3-VL-32B",       icon: "👁", keywords: ["看图、截图、图片、识别"], desc: "图片/视觉理解任务"),
]

// ─── App Delegate ──────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menubar 图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "🧠"
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = DashboardViewController()
        
        // 每 5 秒刷新
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            (popover.contentViewController as? DashboardViewController)?.refreshData()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @objc func refresh() {
        if popover.isShown {
            (popover.contentViewController as? DashboardViewController)?.refreshData()
        }
    }
}

// ─── View Controller ──────────────────────────────
class DashboardViewController: NSViewController {
    let scrollView = NSScrollView()
    let stackView = NSStackView()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 480))
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshData()
    }
    
    func setupUI() {
        // 标题
        let titleLabel = NSTextField(labelWithString: "🧠 模型路由 Dashboard")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.alignment = .center
        titleLabel.frame = CGRect(x: 0, y: view.frame.height - 38, width: view.frame.width, height: 30)
        view.addSubview(titleLabel)
        
        // 分隔线
        let divider1 = NSBox(frame: CGRect(x: 10, y: view.frame.height - 48, width: view.frame.width - 20, height: 1))
        divider1.boxType = .separator
        view.addSubview(divider1)
        
        // ─── 历史记录 ───
        let historyLabel = NSTextField(labelWithString: "📋 最近路由记录")
        historyLabel.font = NSFont.boldSystemFont(ofSize: 12)
        historyLabel.frame = CGRect(x: 12, y: view.frame.height - 70, width: 200, height: 20)
        view.addSubview(historyLabel)
        
        // ScrollView (左半区: 历史)
        scrollView.frame = CGRect(x: 10, y: 100, width: view.frame.width - 20, height: view.frame.height - 175)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        
        let clipView = NSClipView()
        clipView.documentView = stackView
        scrollView.contentView = clipView
        
        view.addSubview(scrollView)
        
        // ─── 规则概览 ───
        let rulesDivider = NSBox(frame: CGRect(x: 10, y: 90, width: view.frame.width - 20, height: 1))
        rulesDivider.boxType = .separator
        view.addSubview(rulesDivider)
        
        let rulesLabel = NSTextField(labelWithString: "⚙️ 路由规则")
        rulesLabel.font = NSFont.boldSystemFont(ofSize: 12)
        rulesLabel.frame = CGRect(x: 12, y: 65, width: 200, height: 20)
        view.addSubview(rulesLabel)
        
        var yOffset: CGFloat = 45
        for rule in rules {
            let ruleText = NSTextField(labelWithString: "\(rule.icon) \(rule.model)")
            ruleText.font = NSFont.systemFont(ofSize: 11)
            ruleText.frame = CGRect(x: 14, y: yOffset, width: 300, height: 16)
            view.addSubview(ruleText)
            yOffset -= 16
        }
        
        // 刷新按钮
        let refreshBtn = NSButton(title: "⟳ 刷新", target: self, action: #selector(refreshData))
        refreshBtn.bezelStyle = .rounded
        refreshBtn.font = NSFont.systemFont(ofSize: 11)
        refreshBtn.frame = CGRect(x: view.frame.width - 75, y: view.frame.height - 72, width: 65, height: 22)
        view.addSubview(refreshBtn)
    }
    
    @objc func refreshData() {
        // 清除旧条目
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let entries = loadHistory()
        
        if entries.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "暂无路由记录\n按 ⌥M 触发路由后记录将显示在此")
            emptyLabel.font = NSFont.systemFont(ofSize: 12)
            emptyLabel.textColor = NSColor.secondaryLabelColor
            emptyLabel.alignment = .center
            stackView.addArrangedSubview(emptyLabel)
            return
        }
        
        for entry in entries.reversed() {
            let rowView = createRouteRow(entry: entry)
            stackView.addArrangedSubview(rowView)
        }
    }
    
    func createRouteRow(entry: RouteEntry) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: scrollView.frame.width - 20, height: 48))
        row.wantsLayer = true
        row.layer?.cornerRadius = 6
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 时间
        let timeLabel = NSTextField(labelWithString: formatTime(entry.timestamp))
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        timeLabel.textColor = NSColor.secondaryLabelColor
        timeLabel.frame = CGRect(x: 6, y: 28, width: 130, height: 14)
        row.addSubview(timeLabel)
        
        // 模型 + 原因
        let modelLabel = NSTextField(labelWithString: "\(modelIcon(entry.model)) \(entry.model)")
        modelLabel.font = NSFont.boldSystemFont(ofSize: 11)
        modelLabel.frame = CGRect(x: 6, y: 12, width: 200, height: 16)
        row.addSubview(modelLabel)
        
        let reasonLabel = NSTextField(labelWithString: entry.reason)
        reasonLabel.font = NSFont.systemFont(ofSize: 10)
        reasonLabel.textColor = NSColor.secondaryLabelColor
        reasonLabel.frame = CGRect(x: 6, y: 0, width: 200, height: 14)
        row.addSubview(reasonLabel)
        
        // 内容预览
        let previewLabel = NSTextField(labelWithString: "「\(entry.preview)」")
        previewLabel.font = NSFont.systemFont(ofSize: 10)
        previewLabel.textColor = NSColor.tertiaryLabelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.frame = CGRect(x: 140, y: 0, width: scrollView.frame.width - 160, height: 36)
        row.addSubview(previewLabel)
        
        return row
    }
    
    func modelIcon(_ model: String) -> String {
        if model.contains("Coder") { return "🛠" }
        if model.contains("VL") { return "👁" }
        if model.contains("Flash") { return "⚡" }
        return "🧠"
    }
    
    func formatTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df.string(from: date)
    }
}

// ─── 启动 ──────────────────────────────────────────
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // 无 Dock 图标
app.run()
