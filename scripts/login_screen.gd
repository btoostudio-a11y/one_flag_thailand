extends Control
var email: LineEdit
var password: LineEdit
var display_name: LineEdit
var status: Label
var busy := false
var actions: Array[Button] = []

func _ready() -> void:
	var background := ColorRect.new()
	UIFactory.fill_parent(background)
	background.color = Color("#08295c")
	add_child(background)
	var stack := VBoxContainer.new()
	stack.position = Vector2(100,180)
	stack.size = Vector2(880,1400)
	stack.add_theme_constant_override("separation",24)
	add_child(stack)
	var title := UIFactory.make_label("YOUR ACCOUNT",72,Color("#ffe04b"))
	title.custom_minimum_size = Vector2(880,140)
	stack.add_child(title)
	status = UIFactory.make_label("Guest scores are already saved.\nAn account keeps them under your name.",32)
	status.custom_minimum_size = Vector2(880,180)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(status)
	if SupabaseClient.is_logged_in():
		status.text = "Signed in as " + SupabaseClient.get_user_name()
		add_action(stack,"LINK SAVED SCORES",func(): set_busy(true); await SupabaseClient.claim_scores(); status.text = "Saved rounds checked. Return to your result."; set_busy(false))
		add_action(stack,"SIGN OUT",func(): set_busy(true); await SupabaseClient.logout(); GameManager.request_screen("login"))
	else:
		display_name = field(stack,"Public nickname (not your email)",false)
		email = field(stack,"Email",false)
		password = field(stack,"Password (at least 8 characters)",true)
		add_action(stack,"CREATE ACCOUNT / VERIFY EMAIL",_signup)
		add_action(stack,"LOGIN",_login)
		var hint := UIFactory.make_label("New account: open the confirmation email,\nthen return here and LOGIN.\nYou can keep playing without an account.",30,Color("#8ce7ff"))
		hint.custom_minimum_size = Vector2(880,190)
		stack.add_child(hint)
	add_action(stack,"BACK TO GAME",func(): GameManager.request_screen("result" if not SupabaseClient.last_saved.is_empty() else "start"))

func field(parent: Node, hint: String, secret: bool) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = hint
	input.secret = secret
	input.custom_minimum_size = Vector2(880,105)
	input.add_theme_font_size_override("font_size",32)
	parent.add_child(input)
	return input

func add_action(parent: Node,label: String,callback: Callable) -> void:
	var button := UIFactory.make_button(label,Color("#1769d2"),Vector2(880,115))
	button.pressed.connect(callback)
	parent.add_child(button)
	actions.append(button)

func set_busy(value: bool) -> void:
	busy = value
	for button in actions: button.disabled = value

func _signup() -> void:
	if busy: return
	if not email.text.contains("@") or password.text.length()<8 or display_name.text.strip_edges().is_empty():
		status.text = "Enter a nickname, email and password\n(at least 8 characters)."
		return
	set_busy(true)
	status.text = "Requesting confirmation email..."
	var ok := await SupabaseClient.signup(email.text,password.text,display_name.text)
	status.text = "Check your email and confirm,\nthen return here and LOGIN." if ok else SupabaseClient.last_error
	set_busy(false)

func _login() -> void:
	if busy: return
	set_busy(true)
	status.text = "Signing in and linking saved rounds..."
	var ok := await SupabaseClient.login(email.text,password.text)
	password.text = ""
	if ok: GameManager.request_screen("login")
	else:
		status.text = SupabaseClient.last_error
		set_busy(false)
