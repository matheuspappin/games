# =============================================================================
# social_modal.gd
# Central Social Tática — Estilo Call of Duty (MW3 / Black Ops)
# Abas: Amigos, Convites Pendentes, Jogadores Recentes
# Notificações em Tempo Real com atalhos F1 (Aceitar) / F2 (Recusar)
# =============================================================================
class_name SocialModal
extends Control

signal closed

@onready var tab_btn_friends     : Button         = $Panel/Margin/VBox/TabsHBox/BtnTabFriends
@onready var tab_btn_invites     : Button         = $Panel/Margin/VBox/TabsHBox/BtnTabInvites
@onready var tab_btn_recents     : Button         = $Panel/Margin/VBox/TabsHBox/BtnTabRecents
@onready var btn_close           : Button         = $Panel/Margin/VBox/HeaderHBox/BtnClose
@onready var list_container      : VBoxContainer  = $Panel/Margin/VBox/Scroll/ListVBox
@onready var input_add_name      : LineEdit       = $Panel/Margin/VBox/AddFriendHBox/InputFriendName
@onready var input_add_tag       : LineEdit       = $Panel/Margin/VBox/AddFriendHBox/InputFriendTag
@onready var btn_add_submit      : Button         = $Panel/Margin/VBox/AddFriendHBox/BtnAddSubmit
@onready var lbl_header_title    : Label          = $Panel/Margin/VBox/HeaderHBox/LblTitle

# Banner de notificação instantânea (Top-Right)
@onready var invite_banner       : PanelContainer = $InviteBanner
@onready var lbl_banner_text     : Label          = $InviteBanner/Margin/VBox/LblBannerText
@onready var btn_banner_accept   : Button         = $InviteBanner/Margin/VBox/HBox/BtnAccept
@onready var btn_banner_decline  : Button         = $InviteBanner/Margin/VBox/HBox/BtnDecline

var current_tab: int = 0  # 0 = Friends, 1 = Invites, 2 = Recents
var active_invite: Dictionary = {}
var banner_timer: float = 0.0

func _ready() -> void:
	visible = false
	if invite_banner:
		invite_banner.visible = false

	if tab_btn_friends: tab_btn_friends.pressed.connect(func(): _switch_tab(0))
	if tab_btn_invites: tab_btn_invites.pressed.connect(func(): _switch_tab(1))
	if tab_btn_recents: tab_btn_recents.pressed.connect(func(): _switch_tab(2))
	if btn_close: btn_close.pressed.connect(close)
	if btn_add_submit: btn_add_submit.pressed.connect(_on_add_friend_pressed)

	if btn_banner_accept: btn_banner_accept.pressed.connect(_on_banner_accept)
	if btn_banner_decline: btn_banner_decline.pressed.connect(_on_banner_decline)

	var sm = get_node_or_null("/root/SocialManager")
	if sm:
		sm.friends_updated.connect(_on_data_updated)
		sm.recent_players_updated.connect(_on_data_updated)
		sm.invite_received.connect(_show_invite_notification)

	_switch_tab(0)

func _process(delta: float) -> void:
	if invite_banner and invite_banner.visible:
		banner_timer -= delta
		if banner_timer <= 0.0:
			invite_banner.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# Atalhos globais de convite F1 / F2
		if invite_banner and invite_banner.visible:
			if event.keycode == KEY_F1:
				_on_banner_accept()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_F2 and visible == false:
				_on_banner_decline()
				get_viewport().set_input_as_handled()
				return

		# Atalho para abrir/fechar Social Hub: F2 ou tecla O
		if event.keycode == KEY_F2 and (not invite_banner or not invite_banner.visible):
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close()
			get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	_refresh_view()

func close() -> void:
	visible = false
	closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _switch_tab(tab_idx: int) -> void:
	current_tab = tab_idx
	if tab_btn_friends:
		tab_btn_friends.modulate = Color(1.3, 1.3, 1.3, 1.0) if tab_idx == 0 else Color(0.65, 0.7, 0.8, 0.7)
	if tab_btn_invites:
		tab_btn_invites.modulate = Color(1.3, 1.3, 1.3, 1.0) if tab_idx == 1 else Color(0.65, 0.7, 0.8, 0.7)
	if tab_btn_recents:
		tab_btn_recents.modulate = Color(1.3, 1.3, 1.3, 1.0) if tab_idx == 2 else Color(0.65, 0.7, 0.8, 0.7)
	_refresh_view()

func _on_data_updated() -> void:
	if visible:
		_refresh_view()

func _refresh_view() -> void:
	if not list_container: return

	for child in list_container.get_children():
		child.queue_free()

	var sm = get_node_or_null("/root/SocialManager")
	if not sm: return

	match current_tab:
		0: _render_friends_tab(sm.get_friends())
		1: _render_invites_tab(sm.pending_invites)
		2: _render_recents_tab(sm.recent_players)

# ── ABA AMIGOS ─────────────────────────────────────────────────────────────────
func _render_friends_tab(friends: Array[Dictionary]) -> void:
	if friends.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Nenhum amigo adicionado ainda. Digite um nome abaixo para adicionar seu esquadrão!"
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)
		return

	for f in friends:
		var row = _create_friend_card(f)
		list_container.add_child(row)

func _create_friend_card(f: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.92)
	style.border_width_left = 3
	style.border_color = Color(0.2, 0.8, 1.0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var rank_lbl = Label.new()
	rank_lbl.text = "%s %d" % [str(f.get("rank_icon", "★")), int(f.get("level", 50))]
	var col_raw = f.get("rank_color", Color(1.0, 0.8, 0.2))
	if col_raw is Color:
		rank_lbl.modulate = col_raw
	else:
		rank_lbl.modulate = Color.from_string(str(col_raw), Color(1.0, 0.8, 0.2))
	hbox.add_child(rank_lbl)

	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_vbox)

	var name_lbl = Label.new()
	name_lbl.text = "%s %s" % [str(f.get("tag", "[TF141]")), str(f.get("name", "Operador"))]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_vbox.add_child(name_lbl)

	var status_lbl = Label.new()
	status_lbl.text = str(f.get("status", "Online"))
	status_lbl.modulate = Color(0.3, 0.9, 0.4, 0.85) if status_lbl.text.contains("Online") or status_lbl.text.contains("Lobby") else Color(0.7, 0.7, 0.7, 0.7)
	status_lbl.add_theme_font_size_override("font_size", 12)
	name_vbox.add_child(status_lbl)

	# Botão Convidar para Sala
	var btn_invite = Button.new()
	btn_invite.text = "🎮 CONVIDAR"
	btn_invite.pressed.connect(func():
		var nm = get_node_or_null("/root/NetworkManager")
		var code = nm.current_room_code if nm else ""
		if code.is_empty():
			# Se não tem sala aberta, gera ou usa local
			code = "COD-1V1"
		var sm = get_node_or_null("/root/SocialManager")
		if sm:
			sm.send_invite(str(f.get("name")), code, "NUKETOWN 2065")
		btn_invite.text = "✔ CONVITE ENVIADO"
		btn_invite.disabled = true
	)
	hbox.add_child(btn_invite)

	# Botão Remover Amigo
	var btn_del = Button.new()
	btn_del.text = "✕"
	btn_del.pressed.connect(func():
		var sm = get_node_or_null("/root/SocialManager")
		if sm: sm.remove_friend(str(f.get("name")))
	)
	hbox.add_child(btn_del)

	return panel

# ── ABA CONVITES ───────────────────────────────────────────────────────────────
func _render_invites_tab(invites: Array[Dictionary]) -> void:
	if invites.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Nenhum convite pendente no momento."
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)
		return

	for inv in invites:
		var panel = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.set_content_margin_all(10)
		panel.add_child(margin)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		margin.add_child(hbox)

		var info_lbl = Label.new()
		info_lbl.text = "%s %s convidou você para DUELO em %s (Sala: %s)" % [
			str(inv.get("tag", "")), str(inv.get("inviter", "Operador")), str(inv.get("map", "Nuketown")), str(inv.get("room_code", ""))
		]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_lbl)

		var btn_acc = Button.new()
		btn_acc.text = "✔ ACEITAR"
		btn_acc.pressed.connect(func():
			var sm = get_node_or_null("/root/SocialManager")
			if sm: sm.accept_invite(inv)
			close()
		)
		hbox.add_child(btn_acc)

		var btn_dec = Button.new()
		btn_dec.text = "✖ RECUSAR"
		btn_dec.pressed.connect(func():
			var sm = get_node_or_null("/root/SocialManager")
			if sm: sm.decline_invite(inv)
			_refresh_view()
		)
		hbox.add_child(btn_dec)

		list_container.add_child(panel)

# ── ABA RECENTES ───────────────────────────────────────────────────────────────
func _render_recents_tab(recents: Array[Dictionary]) -> void:
	if recents.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Nenhum operador recente registrado. Jogue um duelo para encontrar adversários!"
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)
		return

	for r in recents:
		var panel = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.set_content_margin_all(8)
		panel.add_child(margin)

		var hbox = HBoxContainer.new()
		margin.add_child(hbox)

		var lbl = Label.new()
		lbl.text = "%s %s  •  %s  (%s)" % [str(r.get("tag", "")), str(r.get("name", "")), str(r.get("mode", "")), str(r.get("date", ""))]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var btn_add = Button.new()
		btn_add.text = "+ AMIGO"
		btn_add.pressed.connect(func():
			var sm = get_node_or_null("/root/SocialManager")
			if sm:
				sm.add_friend(str(r.get("name")), str(r.get("tag", "[TF141]")))
				btn_add.text = "✔ ADICIONADO"
				btn_add.disabled = true
		)
		hbox.add_child(btn_add)

		list_container.add_child(panel)

func _on_add_friend_pressed() -> void:
	if not input_add_name: return
	var name_val = input_add_name.text.strip_edges()
	var tag_val = input_add_tag.text.strip_edges() if input_add_tag and input_add_tag.text != "" else "[TF141]"

	if not name_val.is_empty():
		var sm = get_node_or_null("/root/SocialManager")
		if sm:
			sm.add_friend(name_val, tag_val)
			input_add_name.text = ""
			_refresh_view()

# ── NOTIFICAÇÃO BANNER POP-UP (ESTILO COD) ────────────────────────────────────
func _show_invite_notification(invite: Dictionary) -> void:
	active_invite = invite
	banner_timer = 12.0
	if invite_banner:
		invite_banner.visible = true
	if lbl_banner_text:
		lbl_banner_text.text = "🔔 CONVITE DE GRUPO: %s %s convidou você para DUELO 1V1 em %s!\n[F1] Aceitar  •  [F2] Recusar" % [
			str(invite.get("tag", "")), str(invite.get("inviter", "Operador")), str(invite.get("map", "Nuketown"))
		]

func _on_banner_accept() -> void:
	if invite_banner:
		invite_banner.visible = false
	if not active_invite.is_empty():
		var sm = get_node_or_null("/root/SocialManager")
		if sm:
			sm.accept_invite(active_invite)
		active_invite.clear()

func _on_banner_decline() -> void:
	if invite_banner:
		invite_banner.visible = false
	if not active_invite.is_empty():
		var sm = get_node_or_null("/root/SocialManager")
		if sm:
			sm.decline_invite(active_invite)
		active_invite.clear()
