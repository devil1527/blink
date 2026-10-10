extends Node2D

# DON'T BLINK — one-touch endless runner prototype for Godot 4.x.
# Everything is drawn with vector shapes, so no external assets are required.

const BASE_SPEED := 255.0
const BLINK_DURATION := 0.23
const BLINK_COOLDOWN := 1.20
const PLAYER_X_RATIO := 0.245
const PLAYER_SIZE := 17.0
const FLOOR_RATIO := 0.79
const GATE_WIDTH := 34.0
const GAP_MIN := 190.0
const GAP_MAX := 255.0

enum Mode { TITLE, PLAYING, DEAD, PAUSED }

var mode: Mode = Mode.TITLE
var screen_size := Vector2(480, 854)
var player_pos := Vector2.ZERO
var blink_left := 0.0
var cooldown_left := 0.0
var elapsed := 0.0
var score := 0
var best_score := 0
var speed := BASE_SPEED
var spawn_timer := 0.0
var obstacles: Array[Dictionary] = []
var shake := 0.0
var last_touch_ms := -1000
var sound_enabled := true

var bg_stars: Array[Vector3] = []

func _ready() -> void:
    screen_size = get_viewport_rect().size
    player_pos = Vector2(screen_size.x * PLAYER_X_RATIO, screen_size.y * FLOOR_RATIO - 42.0)
    best_score = int(ConfigFile.new().get_value("scores", "best", 0))
    _load_best()
    _make_stars()
    get_viewport().size_changed.connect(_on_resize)
    queue_redraw()

func _load_best() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://save.cfg") == OK:
        best_score = int(cfg.get_value("scores", "best", 0))

func _save_best() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("scores", "best", best_score)
    cfg.save("user://save.cfg")

func _make_stars() -> void:
    bg_stars.clear()
    for i in range(48):
        bg_stars.append(Vector3(randf_range(0, screen_size.x), randf_range(0, screen_size.y), randf_range(0.25, 1.0)))

func _on_resize() -> void:
    screen_size = get_viewport_rect().size
    player_pos.x = screen_size.x * PLAYER_X_RATIO
    player_pos.y = screen_size.y * FLOOR_RATIO - 42.0
    _make_stars()
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
            if mode == Mode.PLAYING:
                mode = Mode.PAUSED
            elif mode == Mode.PAUSED:
                mode = Mode.PLAYING
            elif mode == Mode.DEAD:
                _start_game()
            else:
                mode = Mode.TITLE
            queue_redraw()
            return
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            _primary_action()
    elif event is InputEventScreenTouch and event.pressed:
        _primary_action()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _primary_action()

func _primary_action() -> void:
    var now := Time.get_ticks_msec()
    # Avoid touch + synthesized mouse events triggering the same action twice.
    if now - last_touch_ms < 80:
        return
    last_touch_ms = now

    match mode:
        Mode.TITLE:
            _start_game()
        Mode.PLAYING:
            _try_blink()
        Mode.DEAD:
            _start_game()
        Mode.PAUSED:
            mode = Mode.PLAYING
    queue_redraw()

func _start_game() -> void:
    mode = Mode.PLAYING
    score = 0
    elapsed = 0.0
    speed = BASE_SPEED
    blink_left = 0.0
    cooldown_left = 0.0
    spawn_timer = 0.65
    shake = 0.0
    obstacles.clear()
    player_pos = Vector2(screen_size.x * PLAYER_X_RATIO, screen_size.y * FLOOR_RATIO - 42.0)
    _spawn_obstacle(screen_size.x + 130.0)

func _try_blink() -> void:
    if cooldown_left <= 0.0:
        blink_left = BLINK_DURATION
        cooldown_left = BLINK_COOLDOWN
        if OS.has_feature("android"):
            Input.vibrate_handheld(35)

func _spawn_obstacle(start_x: float) -> void:
    # Gates alternate between a phaseable blue barrier and a red hazard.
    # A generous horizontal gap and spacing keeps the early game fair.
    var kind := "gate"
    if score > 1 and randf() < min(0.22 + elapsed * 0.008, 0.42):
        kind = "hazard"
    var floor_y := screen_size.y * FLOOR_RATIO
    var h := randf_range(75.0, 125.0) if kind == "gate" else randf_range(55.0, 105.0)
    obstacles.append({
        "x": start_x,
        "kind": kind,
        "h": h,
        "passed": false,
        "wobble": randf_range(0.0, TAU)
    })

func _process(delta: float) -> void:
    screen_size = get_viewport_rect().size
    if mode == Mode.PLAYING:
        elapsed += delta
        speed = BASE_SPEED + min(elapsed * 2.2, 170.0)
        blink_left = maxf(0.0, blink_left - delta)
        cooldown_left = maxf(0.0, cooldown_left - delta)
        spawn_timer -= delta
        if spawn_timer <= 0.0:
            _spawn_obstacle(screen_size.x + 45.0)
            spawn_timer = maxf(0.86, randf_range(1.18, 1.55) - elapsed * 0.003)
        _update_obstacles(delta)
        _check_collisions()
    elif mode == Mode.DEAD:
        shake = maxf(0.0, shake - delta * 24.0)
    queue_redraw()

func _update_obstacles(delta: float) -> void:
    var floor_y := screen_size.y * FLOOR_RATIO
    for o in obstacles:
        o.x = float(o.x) - speed * delta
        if not o.passed and float(o.x) + GATE_WIDTH < player_pos.x:
            o.passed = true
            score += 1
            if score > best_score:
                best_score = score
                _save_best()
    var kept: Array[Dictionary] = []
    for o in obstacles:
        if float(o.x) > -80.0:
            kept.append(o)
    obstacles = kept

func _check_collisions() -> void:
    var player_rect := Rect2(player_pos - Vector2(PLAYER_SIZE, PLAYER_SIZE), Vector2(PLAYER_SIZE * 2.0, PLAYER_SIZE * 2.0))
    for o in obstacles:
        var x := float(o.x)
        var h := float(o.h)
        var floor_y := screen_size.y * FLOOR_RATIO
        var rect := Rect2(x - GATE_WIDTH * 0.5, floor_y - h, GATE_WIDTH, h)
        if player_rect.intersects(rect):
            if String(o.kind) == "gate":
                # Blue gate: passing through requires an active blink.
                if blink_left <= 0.0:
                    _die()
                    return
            else:
                # Red hazard: do NOT blink while overlapping it.
                if blink_left > 0.0:
                    _die()
                    return

func _die() -> void:
    mode = Mode.DEAD
    shake = 8.0
    if score > best_score:
        best_score = score
        _save_best()

func _draw() -> void:
    var w := screen_size.x
    var h := screen_size.y
    var floor_y := h * FLOOR_RATIO

    # Background and subtle stars.
    draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#070b1c"))
    for i in range(bg_stars.size()):
        var s := bg_stars[i]
        var drift_x := fposmod(s.x - elapsed * (12.0 + s.z * 25.0), w)
        var alpha := 0.2 + s.z * 0.55
        draw_circle(Vector2(drift_x, s.y), 0.7 + s.z * 1.3, Color(0.40, 0.72, 1.0, alpha))
    # Ambient floor grid.
    draw_line(Vector2(0, floor_y), Vector2(w, floor_y), Color("#1c3656"), 2.0)
    for i in range(1, 12):
        var xx := fposmod(float(i) * 68.0 - elapsed * speed * 0.45, w)
        draw_line(Vector2(xx, floor_y), Vector2(xx - 75, h), Color(0.12, 0.32, 0.48, 0.22), 1.0)
    for j in range(1, 5):
        var yy := floor_y + float(j) * 28.0
        draw_line(Vector2(0, yy), Vector2(w, yy), Color(0.12, 0.32, 0.48, 0.18), 1.0)

    # Obstacles.
    for o in obstacles:
        var x := float(o.x)
        var oh := float(o.h)
        var r := Rect2(x - GATE_WIDTH * 0.5, floor_y - oh, GATE_WIDTH, oh)
        if String(o.kind) == "gate":
            draw_rect(r.grow(5), Color(0.0, 0.86, 1.0, 0.10))
            draw_rect(r, Color("#12c8ff"))
            draw_rect(Rect2(r.position + Vector2(7, 0), Vector2(5, oh)), Color("#b5f5ff"))
            draw_line(Vector2(r.position.x - 7, r.position.y + 8), Vector2(r.end.x + 7, r.position.y + 8), Color("#d9fbff"), 2.0)
        else:
            draw_rect(r.grow(5), Color(1.0, 0.12, 0.24, 0.12))
            draw_rect(r, Color("#ff3155"))
            for k in range(3):
                var sy := r.position.y + 12 + k * 24
                if sy < r.end.y - 4:
                    draw_line(Vector2(r.position.x + 5, sy), Vector2(r.end.x - 5, sy + 8), Color("#ffd2da"), 2.0)

    # Player glow and body.
    var is_blinking := blink_left > 0.0
    var body_color := Color("#b7ffff") if is_blinking else Color("#f5fbff")
    var glow_color := Color(0.0, 0.9, 1.0, 0.18 if is_blinking else 0.08)
    draw_circle(player_pos, 31 if is_blinking else 24, glow_color)
    draw_circle(player_pos, PLAYER_SIZE + 3, Color("#26dfff") if is_blinking else Color("#577bff"))
    draw_circle(player_pos, PLAYER_SIZE - 2, body_color)
    draw_circle(player_pos + Vector2(5, -4), 3.0, Color("#071126"))

    # HUD.
    if mode == Mode.PLAYING or mode == Mode.PAUSED or mode == Mode.DEAD:
        _draw_text_center(str(score), Vector2(w * 0.5, 70), 48, Color("#f4fbff"))
        draw_string(ThemeDB.fallback_font, Vector2(20, 42), "BEST %d" % best_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8ca4c8"))
        _draw_text_center("BLINK READY" if cooldown_left <= 0 else "RECHARGING %.1f" % cooldown_left, Vector2(w * 0.5, floor_y + 57), 16, Color("#70eaff") if cooldown_left <= 0 else Color("#8190ab"))
        # Cooldown bar.
        var bar_w := w * 0.48
        var bar := Rect2((w - bar_w) * 0.5, floor_y + 72, bar_w, 5)
        draw_rect(bar, Color("#17233d"))
        draw_rect(Rect2(bar.position, Vector2(bar_w * (1.0 - cooldown_left / BLINK_COOLDOWN), 5)), Color("#12c8ff"))

    if mode == Mode.TITLE:
        _draw_text_center("DON'T", Vector2(w * 0.5, h * 0.24), 25, Color("#7feaff"))
        _draw_text_center("BLINK", Vector2(w * 0.5, h * 0.24 + 55), 55, Color("#f6fbff"))
        _draw_text_center("ONE TAP. ONE BLINK.", Vector2(w * 0.5, h * 0.24 + 103), 15, Color("#8ca4c8"))
        _draw_button(w * 0.5, h * 0.63, "TAP TO START", Color("#12c8ff"))
        _draw_text_center("BLINK BLUE  •  NEVER BLINK RED", Vector2(w * 0.5, h * 0.73), 12, Color("#8190ab"))
        _draw_text_center("HOW LONG CAN YOU LAST?", Vector2(w * 0.5, h * 0.77), 12, Color("#536989"))

    elif mode == Mode.DEAD:
        draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.01, 0.02, 0.06, 0.62))
        _draw_text_center("YOU BLINKED.", Vector2(w * 0.5, h * 0.37), 28, Color("#ff5470"))
        _draw_text_center("SCORE  %d" % score, Vector2(w * 0.5, h * 0.43), 22, Color("#f4fbff"))
        _draw_text_center("BEST  %d" % best_score, Vector2(w * 0.5, h * 0.48), 16, Color("#8ca4c8"))
        _draw_button(w * 0.5, h * 0.59, "TAP TO RETRY", Color("#12c8ff"))
        _draw_text_center("TIP: BLINK THROUGH BLUE. PASS RED WITHOUT BLINKING.", Vector2(w * 0.5, h * 0.69), 11, Color("#8ca4c8"))

    elif mode == Mode.PAUSED:
        draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.01, 0.02, 0.06, 0.65))
        _draw_text_center("PAUSED", Vector2(w * 0.5, h * 0.42), 32, Color("#f4fbff"))
        _draw_button(w * 0.5, h * 0.53, "TAP TO RESUME", Color("#12c8ff"))

    # Button for active gameplay.
    if mode == Mode.PLAYING:
        var btn_center := Vector2(w * 0.5, h * 0.91)
        var ready := cooldown_left <= 0.0
        draw_circle(btn_center, 54, Color(0.0, 0.8, 1.0, 0.09 if ready else 0.025))
        draw_circle(btn_center, 44, Color("#12c8ff") if ready else Color("#283650"))
        draw_circle(btn_center, 36, Color("#0b1730"))
        _draw_text_center("BLINK" if ready else "%.1f" % cooldown_left, btn_center + Vector2(0, 5), 17, Color("#c7faff") if ready else Color("#7285a5"))
        draw_string(ThemeDB.fallback_font, Vector2(20, h - 20), "ESC / BACK = PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#405575"))

func _draw_text_center(text_value: String, center: Vector2, font_size: int, color: Color) -> void:
    var font := ThemeDB.fallback_font
    var text_size := font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.34), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_button(cx: float, cy: float, label: String, color: Color) -> void:
    var rect := Rect2(cx - 115, cy - 25, 230, 50)
    draw_rect(rect.grow(5), Color(color.r, color.g, color.b, 0.10), true, 12)
    draw_rect(rect, color, true, 12)
    _draw_text_center(label, Vector2(cx, cy), 16, Color("#061225"))
