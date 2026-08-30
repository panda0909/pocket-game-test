extends Node

## 開發用擷圖工具：載入主場景、等指定幀數、把畫面存成 PNG 後結束。
## 有了它就能在沒有人盯著螢幕的情況下確認畫面真的畫出東西。
##
## 用法：
##     Godot --path . tools/capture.tscn -- <輸出路徑> <等待幀數>
##
## 這個場景不會被匯出（export_presets.cfg 已排除 tools/）。

const DEFAULT_FRAMES := 90
const DEFAULT_OUTPUT := "/tmp/godot_capture.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else DEFAULT_OUTPUT
	var frames: int = int(args[1]) if args.size() > 1 else DEFAULT_FRAMES

	add_child(load("res://scenes/main.tscn").instantiate())
	var main: Node = get_child(0)
	var capture_mode := args[2] if args.size() > 2 else "title"
	if capture_mode == "game" or capture_mode == "tiers":
		# 讓開發截圖直接進到可觀察的戰鬥狀態：多隻守衛、敵人、投射物與 HUD。
		await get_tree().process_frame
		main.get_node("HUD").start_game.emit()
		main._economy.gold = 100000
		if capture_mode == "tiers":
			# 展示每種原角色的四段裝備成長，確認圖集裁切與去背都可用。
			main._board.clear_all()
			main.get_node("Playfield/BoardView").clear_all()
			for i in Board.cell_count():
				var kind := i % 3
				var tier := (i % 4) + 1
				main._board.place(i, kind, tier)
				main.get_node("Playfield/BoardView").add_unit(i, kind, tier)
		else:
			for i in mini(8, Board.cell_count()):
				main.get_node("HUD").summon_requested.emit()
				await get_tree().process_frame
		main._wave_time_left = 0.2

	# 等畫面真的畫過幾幀，否則擷到的會是還沒繪製的空白緩衝區
	for i in frames:
		await get_tree().process_frame
	if capture_mode == "game" or capture_mode == "tiers":
		print("截圖狀態 wave=%d time=%.2f effects=%d enemies=%d" % [
				main._wave, main._wave_time_left, main.get_node("Playfield/Effects").get_child_count(),
			get_tree().get_nodes_in_group("enemy").size()
		])

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("擷圖失敗：%s" % error_string(error))
		get_tree().quit(1)
		return
	print("已擷圖 %s %s" % [out_path, image.get_size()])
	get_tree().quit()
