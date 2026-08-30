class_name Targeting
extends RefCounted

## 選敵規則。抽成純函式的好處是可以直接餵假資料測試，
## 不必在場景裡擺出各種敵人位置的組合。


## 從候選中挑出射程內、沿軌道走得最遠（最接近金庫）的敵人。
## candidates 每個元素需含 "position": Vector2 與 "progress": float。
## 沒有合適目標時回傳 null。
static func select(origin: Vector2, attack_range: float, candidates: Array):
	var best = null
	var best_progress := -1.0
	for candidate in candidates:
		var position: Vector2 = candidate["position"]
		if origin.distance_to(position) > attack_range:
			continue
		var progress: float = candidate["progress"]
		if progress > best_progress:
			best_progress = progress
			best = candidate
	return best
