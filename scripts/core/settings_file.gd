extends RefCounted

const FORMAT := "dead-platform-settings"
const VERSION := 1
const MAX_BYTES := 1024*1024
const SECTIONS := ["movement","shooting","camera"]

static func write_file(path: String,settings: Dictionary) -> Error:
	var data := {"format":FORMAT,"version":VERSION}
	for section in SECTIONS: data[section] = settings[section].as_dictionary()
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.flush()
	var result := file.get_error()
	file.close()
	return result

static func read_file(path: String,defaults: Dictionary) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Не удалось открыть файл (%d)." % FileAccess.get_open_error()}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"error":"Файл настроек слишком большой (максимум 1 МБ)."}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"error":"Ошибка JSON в строке %d: %s" % [json.get_error_line(),json.get_error_message()]}
	var data = json.data
	if not data is Dictionary or data.get("format") != FORMAT:
		return {"error":"Это не файл настроек «Мёртвого перрона»."}
	var version = data.get("version")
	if not (version is int or version is float) or version != VERSION:
		return {"error":"Версия файла не поддерживается (нужна версия %d)." % VERSION}
	var values := {}
	var adjusted := false
	# Validate every section before touching any active resource. Missing keys
	# use project defaults so older presets remain independent of current edits.
	for section in SECTIONS:
		if not data.get(section) is Dictionary:
			return {"error":"В файле отсутствует раздел %s." % section}
		var candidate: Resource = defaults[section].duplicate()
		var merged: Dictionary = candidate.as_dictionary()
		for key in merged:
			if not data[section].has(key): continue
			var value = data[section][key]
			if merged[key] is bool:
				if not value is bool: return {"error":"%s.%s: нужно true или false." % [section,key]}
			elif not (value is int or value is float) or not is_finite(float(value)):
				return {"error":"%s.%s: нужно конечное число." % [section,key]}
			elif key == "fire_mode" and value != 0 and value != 1:
				return {"error":"shooting.fire_mode: 0 — автоматический, 1 — одиночный."}
			merged[key] = value
		candidate.apply_values(merged)
		values[section] = candidate.as_dictionary()
		adjusted = adjusted or values[section] != merged
	return {"values":values,"adjusted":adjusted}
