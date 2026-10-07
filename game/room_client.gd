extends Node
## Discovery only; ENet admission and gameplay remain separate owners.

signal ticket_received(ticket: Dictionary)
signal failed(message: String)

const PROTOCOL := 1
const ERRORS := {
	"invalid_room_id": "Use 3–24 letters, digits or hyphens for the room ID.",
	"invalid_password": "Password must be at most 128 UTF-8 bytes.",
	"unknown_room": "Room not found. Check the ID and try again.",
	"duplicate_room_id": "That ID is already taken. Join it or choose another.",
	"bad_password": "Wrong password. Re-enter it and try again.",
	"room_full": "Room is full. Wait for a free slot and try again.",
	"incompatible_version": "Build mismatch. Install the same client/server build.",
	"match_in_progress": "Match in progress. Join when the room returns to lobby.",
	"rate_limited": "Too many attempts. Wait a minute and try again.",
	"service_full": "All servers are busy. Try again shortly.",
	"server_start_failed": "Room server could not start. Try creating again.",
	"server_start_timeout": "Room server startup timed out. Try again.",
	"service_stopping": "Room service is restarting. Try again shortly.",
}

var service_url := ""
var busy := false
var request: HTTPRequest


func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 20.0
	request.body_size_limit = 4096
	request.max_redirects = 0
	add_child(request)
	request.request_completed.connect(_completed)


func lookup(create: bool, room_id: String, password: String) -> void:
	if busy:
		return
	if service_url.is_empty():
		failed.emit("Room service is not configured. See the play guide.")
		return
	var url := service_url.trim_suffix("/")
	var loopback := RegEx.create_from_string("^http://127\\.0\\.0\\.1:[0-9]{1,5}$").search(url) != null
	if not url.begins_with("https://") and not loopback:
		failed.emit("Room service requires HTTPS (HTTP is loopback-only).")
		return
	room_id = room_id.strip_edges().to_upper()
	if not (create and room_id.is_empty()) and RegEx.create_from_string("^[A-Z0-9][A-Z0-9-]{2,23}$").search(room_id) == null:
		failed.emit(ERRORS.invalid_room_id)
		return
	if password.to_utf8_buffer().size() > 128:
		failed.emit(ERRORS.invalid_password)
		return
	var payload := {"protocol": PROTOCOL, "build": ProjectSettings.get_setting("build/revision", "development"), "room_id": room_id, "password": password}
	busy = true
	var error := request.request(url + ("/v1/rooms/create" if create else "/v1/rooms/join"), ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		busy = false
		failed.emit("Room service unavailable. Check the connection and retry.")


func cancel() -> void:
	request.cancel_request()
	busy = false


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Room service unavailable or timed out. Check connection and retry.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		failed.emit("Invalid room-service response. Try again or contact the operator.")
		return
	if code != 200:
		failed.emit(ERRORS.get(parsed.get("error", ""), "Room service rejected the request. Try again."))
		return
	if parsed.get("protocol") != PROTOCOL or parsed.get("build") != ProjectSettings.get_setting("build/revision", "development"):
		failed.emit(ERRORS.incompatible_version)
		return
	if not parsed.get("room_id") is String or not parsed.get("address") is String or not parsed.get("token") is String or not (parsed.get("port") is float or parsed.get("port") is int):
		failed.emit("Invalid room-service ticket. Try again or contact the operator.")
		return
	if RegEx.create_from_string("^[A-Z0-9][A-Z0-9-]{2,23}$").search(parsed.room_id) == null or parsed.address.is_empty() or parsed.address.length() > 253 or parsed.token.is_empty() or parsed.token.length() > 128 or parsed.port != int(parsed.port) or parsed.port < 1 or parsed.port > 65535:
		failed.emit("Invalid room-service ticket. Try again or contact the operator.")
		return
	ticket_received.emit(parsed)
