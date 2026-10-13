extends Node
## Anonymous identity owner. Credentials stay out of presentation state and ENet.

signal profile_received(profile: Dictionary)
signal box_opened(receipt: Dictionary)
signal failed(message: String)

const PROTOCOL := 1
const ERRORS := {
	"invalid_profile_credentials": "Profile credentials were rejected. Keep the saved file; do not reset your identity.",
	"profiles_unavailable": "Profiles are not enabled on this service.",
	"profile_store_unavailable": "Profile storage is unavailable. Retry without resetting your identity.",
	"incompatible_version": "Build mismatch. Install the same client/server build.",
	"rate_limited": "Too many attempts. Wait a minute and try again.",
}

var service_url := ""
var credential_path := "" # Optional isolated path for tests; default is scoped to service URL.
var busy := false
var request: HTTPRequest
var _url := ""
var _path := ""
var _identity: Dictionary = {}
var _opening_box := ""


func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 10.0
	request.body_size_limit = 4096
	request.max_redirects = 0 # Never forward a bearer credential to a redirect target.
	add_child(request)
	request.request_completed.connect(_completed)


func ensure_profile() -> void:
	if busy:
		return
	_opening_box = ""
	_url = service_url.trim_suffix("/")
	var loopback := RegEx.create_from_string("^http://127\\.0\\.0\\.1:[0-9]{1,5}$").search(_url) != null
	if not _url.begins_with("https://") and not loopback:
		failed.emit("Profile service requires HTTPS (HTTP is loopback-only).")
		return
	_path = credential_path if not credential_path.is_empty() else "user://profile-%s.json" % _url.sha256_text()
	_identity.clear()
	if FileAccess.file_exists(_path):
		var file := FileAccess.open(_path, FileAccess.READ)
		if file == null or file.get_length() > 4096:
			failed.emit("Saved profile is unreadable. Keep the file; do not reset your identity.")
			return
		var json := JSON.new()
		var parse_error := json.parse(file.get_as_text())
		file.close()
		if parse_error != OK:
			failed.emit("Saved profile is invalid. Keep the file; do not reset your identity.")
			return
		var saved: Variant = json.data
		if not saved is Dictionary or saved.get("service_url") != _url or not _valid_identity(saved):
			failed.emit("Saved profile is invalid or belongs to another service. Keep the file.")
			return
		_identity = saved
	var payload := {"protocol": PROTOCOL, "build": ProjectSettings.get_setting("build/revision", "development")}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var action := "create"
	if not _identity.is_empty():
		action = "fetch"
		payload["profile_id"] = _identity.profile_id
		headers.append("Authorization: Bearer " + _identity.credential)
	busy = true
	if request.request(_url + "/v1/profiles/" + action, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		busy = false
		failed.emit("Profile service unavailable. Retry without resetting your identity.")


func open_box(box_id: String) -> void:
	if busy:
		return
	if _identity.is_empty() or service_url.trim_suffix("/") != _url:
		failed.emit("Fetch your profile before opening a box.")
		return
	_opening_box = box_id
	busy = true
	var payload := {"protocol": PROTOCOL, "build": ProjectSettings.get_setting("build/revision", "development"),
		"profile_id": _identity.profile_id, "box_id": box_id}
	if request.request(_url + "/v1/profiles/open", ["Content-Type: application/json", "Authorization: Bearer " + _identity.credential], HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		busy = false
		failed.emit("Opening unavailable. Retry the same box; no reward was rerolled.")


func cancel() -> void:
	request.cancel_request()
	busy = false
	_identity.clear()


func authorization_header(url: String) -> String:
	if url.trim_suffix("/") != _url or _identity.is_empty():
		return ""
	return "Authorization: Bearer " + _identity.credential


func _valid_identity(value: Dictionary) -> bool:
	return (
		value.get("profile_id") is String and value.get("credential") is String
		and RegEx.create_from_string("^[0-9a-f]{32}$").search(value.profile_id) != null
		and RegEx.create_from_string("^[A-Za-z0-9_-]{43}$").search(value.credential) != null
	)


func _save_identity(value: Dictionary) -> bool:
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	if OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD"]:
		# Set owner-only permissions before writing any secret bytes.
		if FileAccess.set_unix_permissions(temporary, 384) != OK: # 0600
			file.close()
			DirAccess.remove_absolute(temporary)
			return false
	file.store_string(JSON.stringify({"service_url": _url, "profile_id": value.profile_id, "credential": value.credential}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, _path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Profile service unavailable or timed out. Retry without resetting your identity.")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		failed.emit("Invalid profile-service response.")
		return
	var parsed: Dictionary = json.data
	if code != 200:
		failed.emit(ERRORS.get(parsed.get("error", ""), "Profile service rejected the request. Keep your saved identity."))
		return
	if parsed.get("protocol") != PROTOCOL or parsed.get("build") != ProjectSettings.get_setting("build/revision", "development"):
		failed.emit(ERRORS.incompatible_version)
		return
	if not _opening_box.is_empty():
		if parsed.get("box_id") != _opening_box or parsed.get("state") != "opened" or not parsed.get("cosmetic_id") is String:
			failed.emit("Invalid box receipt. Retry the same box.")
			return
		box_opened.emit({"box_id": parsed.box_id, "state": "opened", "cosmetic_id": parsed.cosmetic_id,
			"round_id": parsed.get("round_id", ""), "pool": parsed.get("pool", []),
			"odds": parsed.get("odds", {}), "catalog_version": parsed.get("catalog_version", 1)})
		return
	if not parsed.get("profile_id") is String or not parsed.get("owned") is Array or not parsed.get("equipped") is String or not parsed.get("pending") is Array:
		failed.emit("Invalid profile-service state.")
		return
	for item: Variant in parsed.owned:
		if not item is String:
			failed.emit("Invalid profile-service ownership.")
			return
	if not parsed.equipped in parsed.owned:
		failed.emit("Profile service returned unowned equipment.")
		return
	if _identity.is_empty():
		if not _valid_identity(parsed) or not _save_identity(parsed):
			failed.emit("Could not securely save the new profile. No saved identity was replaced.")
			return
		_identity = {"profile_id": parsed.profile_id, "credential": parsed.credential}
	else:
		if parsed.profile_id != _identity.profile_id:
			failed.emit("Profile service returned a different identity. Keep your saved file.")
			return
	# Never emit credentials with the presentation/ownership state.
	profile_received.emit({"profile_id": parsed.profile_id, "owned": parsed.owned, "equipped": parsed.equipped, "pending": parsed.pending})
