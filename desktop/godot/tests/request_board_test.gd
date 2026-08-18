extends SceneTree

const RequestBoard = preload("res://scripts/request_board.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var board = RequestBoard.new()
    var state: Dictionary = board.default_state()
    var day_one := board.board_cards(state, 1, {"timber": 0, "stone": 0, "ore": 0, "herbs": 2, "fish": 0})
    require(day_one.size() == 3, "day one should expose three board requests")
    require(board.accept_request(state, str(day_one[0].id), 1).get("ok", false), "one request should be accepted from the board")
    require(not board.accept_request(state, str(day_one[1].id), 1).get("ok", false), "a second request should not be accepted while one is active")

    var accepted_id := str(state.get("accepted_id", ""))
    var accepted := board.accepted_request(state, 1)
    require(str(accepted.get("id", "")) == accepted_id, "accepted request should be retrievable")
    require(board.reminder(state, str(accepted.get("requester", "")), {"herbs": 2}, 1).find("request") >= 0, "requester reminder should reflect an active request")

    var completion: Dictionary = board.complete_request(state, accepted_id, 1)
    require(bool(completion.get("ok", false)), "accepted request should complete")
    require(state.get("completed_ids", {}).has(accepted_id), "completion should persist the request id")
    require(str(state.get("accepted_id", "")) == "", "completion should clear the active request")
    require(board.consequence_flags(state).size() == 1, "completion should activate one visible request consequence")
    require(not board.complete_request(state, accepted_id, 1).get("ok", false), "completed request should not complete twice")

    var restored := board.from_dict(board.to_dict(state))
    require(restored.get("completed_ids", {}).has(accepted_id), "request completion should survive normalization")
    var day_two := board.board_cards(restored, 2, {})
    require(day_two.size() == 3, "the next day should rotate three board requests")
    require(day_one[0].get("id", "") != day_two[0].get("id", ""), "request rotation should change the lead request by day")

    var expiry_state: Dictionary = board.default_state()
    var expiry_cards := board.board_cards(expiry_state, 1, {})
    var expiry_id := str(expiry_cards[0].id)
    board.accept_request(expiry_state, expiry_id, 1)
    board.board_cards(expiry_state, 2, {})
    require(expiry_state.get("expired_ids", {}).has(expiry_id), "accepted request should expire when the day advances")
    require(str(expiry_state.get("accepted_id", "")) == "", "expired request should clear the active slot")

    if failures.is_empty():
        print("Godot request board contract: PASS")
        quit(0)
        return
    print("Godot request board contract: FAIL (%d)" % failures.size())
    for failure in failures:
        print(" - ", failure)
    quit(1)
