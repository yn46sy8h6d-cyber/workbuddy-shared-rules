-- model_route.applescript
-- 读取剪贴板内容，判断应使用哪个模型，弹出通知

on run
	set msg to the clipboard as text
	
	if msg is "" then
		display notification "剪贴板为空，请先复制你要发送的消息" with title "模型路由" sound name "Basso"
		return
	end if
	
	set model_name to "DeepSeek-V4-Flash（直连）"
	set reason to "通用任务，默认选择"
	
	-- 代码/编程类
	if msg contains "代码" or msg contains "写代码" or msg contains "函数" or msg contains "debug" or msg contains "Debug" or msg contains "class " or msg contains "重构" or msg contains "写脚本" or msg contains "bug" or msg contains "Bug" or msg contains "编程" or msg contains "程序" or msg contains "API" or msg contains "接口" or msg contains "SQL" or msg contains "JSON" or msg contains "Python" or msg contains "python" or msg contains "JavaScript" or msg contains "Shell" or msg contains "shell" or msg contains "报错" then
		set model_name to "Qwen3-Coder-30B"
		set reason to "检测到编程/代码任务"
	
	-- 视觉/图片类
	else if msg contains "看图" or msg contains "截图" or msg contains "图片" or msg contains "图像" or msg contains "识别" or msg contains "识图" or msg contains "这张" then
		set model_name to "Qwen3-VL-32B（视觉）"
		set reason to "检测到图片/视觉任务"
	
	-- 深度分析类
	else if msg contains "分析" or msg contains "对比" or msg contains "深度" or msg contains "推理" or msg contains "复杂" or msg contains "综合" or msg contains "评估" or msg contains "策略" or msg contains "报告" or msg contains "总结" then
		set model_name to "Qwen3.6-35B"
		set reason to "检测到深度分析任务"
	end if
	
	-- 计算预览
	set msgLen to length of msg
	if msgLen > 60 then
		set msgLen to 60
		set preview to (text 1 thru msgLen of msg) & "..."
	else
		set preview to msg
	end if
	
	-- 弹出通知
	display notification reason & return & "内容: " & preview with title "建议切换: " & model_name sound name "Submarine"
	
end run
