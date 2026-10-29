extends RefCounted

## 参数修改记录存储器：把每次调整的参数快照（含时间戳）按特效类型分别持久化到
## user://fx_history_<type>.json，支持读取、追加与清空。
## Color / Vector2 等不可直接 JSON 化的类型会被转成数组再存回，加载时还原。

const MAX_RECORDS := 50

var effect_type: String = ""
var records: Array = []


func _init(type: String) -> void:
	effect_type = type
	load_records()


func _path() -> String:
	return "user://fx_history_%s.json" % effect_type


## 追加一条记录。params 为「关键参数名 -> 值」的字典，summary 为简明的摘要文本。
## 内存里始终保留真实类型（Color / Vector2），仅在落盘时转成可序列化形式。
func record(params: Dictionary, summary: String) -> void:
	records.append({
		"time": Time.get_unix_time_from_system(),
		"summary": summary,
		"params": params,
	})
	if records.size() > MAX_RECORDS:
		records = records.slice(records.size() - MAX_RECORDS)
	save_records()


func save_records() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		return
	var out := []
	for r in records:
		out.append({
			"time": r["time"],
			"summary": r["summary"],
			"params": _to_storable(r["params"]),
		})
	f.store_string(JSON.stringify({ "records": out }))
	f.close()


func load_records() -> void:
	records = []
	var path := _path()
	if not FileAccess.file_exists(path):
		return
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		return
	var data = JSON.parse_string(txt)
	if data == null or not data.has("records"):
		return
	records = data["records"]
	for r in records:
		if r.has("params"):
			r["params"] = _from_storable(r["params"])


func clear() -> void:
	records = []
	save_records()


func _to_storable(v):
	if v is Dictionary:
		var out := {}
		for k in v.keys():
			out[k] = _to_storable(v[k])
		return out
	if v is Color:
		return ["__color__", v.r, v.g, v.b, v.a]
	if v is Vector2:
		return ["__vec2__", v.x, v.y]
	return v


func _from_storable(v):
	if v is Dictionary:
		var out := {}
		for k in v.keys():
			out[k] = _from_storable(v[k])
		return out
	if v is Array and v.size() >= 1 and v[0] is String:
		if v[0] == "__color__" and v.size() >= 5:
			return Color(v[1], v[2], v[3], v[4])
		if v[0] == "__vec2__" and v.size() >= 3:
			return Vector2(v[1], v[2])
	return v
