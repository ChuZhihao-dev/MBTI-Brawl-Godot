extends BaseFighter
class_name INFJFighter

const LIGHT_QUOTES: Array[String] = ["礼貌微笑!", "我都懂…", "洞察连击!"]

var empathy_shield_timer: float = 0.0
var _shield_pulse: float = 0.0
var _combo_count: int = 0
var _combo_reset_timer: float = 0.0
var _heavy_toggle: int = 0

func _ready() -> void:
	fighter_id = "infj"
	fighter_name = "INFJ"
	theme_color = Color("#10b981")
	super._ready()

func get_active_buff_status() -> String:
	if empathy_shield_timer > 0.0:
		return "共情护盾 %.1fs" % empathy_shield_timer
	return ""

func _physics_process(delta: float) -> void:
	if empathy_shield_timer > 0.0:
		empathy_shield_timer = maxf(0.0, empathy_shield_timer - delta)
		_shield_pulse += delta * 6.0
		if int(floor(_shield_pulse)) != int(floor(_shield_pulse - delta * 6.0)):
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_ember_burst(global_position + Vector2(randf_range(-26.0, 26.0), -44.0), Color("#34d399"), 2)
	if sprite and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("aura_glow", 1.0 if empathy_shield_timer > 0.0 else 0.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("aura_color", Color("#34d399"))

	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(0.0, _combo_reset_timer - delta)
		if _combo_reset_timer <= 0.0:
			_combo_count = 0

	super._physics_process(delta)

func _perform_light_attack() -> void:
	# 轻击 3 段递进：1/2 段单发翡翠灵球，第 3 段高威双连灵球
	_combo_count = (_combo_count % 3) + 1
	_combo_reset_timer = 0.95
	basic_cd = 0.30 if _combo_count < 3 else 0.42
	action_anim_state = "light"
	action_anim_timer = 0.28
	_play_anim("light", true)
	trigger_squash(1.12, 0.90)
	AudioManager.play_sfx("swing_light", -5.0, 1.05 + _combo_count * 0.06)

	var quote: String = LIGHT_QUOTES[_combo_count - 1]
	if _combo_count < 3:
		_spawn_orb(
			Vector2(facing * 36.0, -56.0),
			Vector2(facing * 590.0, 0.0),
			7 + _combo_count,
			Vector2(facing * 190.0, -100.0),
			14.0,
			0.82,
			Color("#34d399"),
			quote
		)
	else:
		# 第 3 段：上下交错双连灵球
		_spawn_orb(Vector2(facing * 38.0, -68.0), Vector2(facing * 640.0, -28.0), 7, Vector2(facing * 240.0, -150.0), 16.0, 0.85, Color("#6ee7b7"), quote)
		_spawn_orb(Vector2(facing * 38.0, -42.0), Vector2(facing * 640.0, 28.0), 7, Vector2(facing * 240.0, -150.0), 16.0, 0.85, Color("#fde047"), "")

func _perform_heavy_attack() -> void:
	# 重击 2 变体交替：1. 中近程灵能震爆法阵（防贴脸）；2. 高速穿透洞察大光球
	_heavy_toggle = (_heavy_toggle + 1) % 2
	_combo_count = 0
	basic_cd = 0.52
	action_anim_state = "heavy"
	action_anim_timer = 0.38
	_play_anim("heavy", true)
	trigger_squash(1.18, 0.86)
	AudioManager.play_sfx("swing_heavy", -3.0, 1.15)
	var vfx := BattleVFX.get_current(get_tree())

	if _heavy_toggle == 1:
		var blast_pos: Vector2 = global_position + Vector2(facing * 84.0, -48.0)
		if vfx:
			vfx.spawn_shockwave_ring(blast_pos, Color("#34d399"), 12.0, 118.0, 0.28, 6.0)
			vfx.spawn_hit_particles(blast_pos, Color("#6ee7b7"), 16, 300.0)
		var hit: bool = _perform_melee(13, Vector2(facing * 350.0, -220.0), true, 148.0)
		if hit and vfx:
			vfx.spawn_floating_text(blast_pos + Vector2(0.0, -54.0), "灵魂震慑!", Color("#fde047"), 1.05)
	else:
		_spawn_orb(
			Vector2(facing * 42.0, -54.0),
			Vector2(facing * 720.0, 0.0),
			14,
			Vector2(facing * 380.0, -210.0),
			22.0,
			0.95,
			Color("#2dd4bf"),
			"看穿你了!"
		)

func on_charge_skill_release(slot: String, level: int, dir: String) -> void:
	var vfx := BattleVFX.get_current(get_tree())
	if slot == "skill1":
		# 洞察预言（U/4）：三档蓄力 + 四向派生
		skill1_cd = 2.9
		action_anim_state = "skill"
		action_anim_timer = 0.44
		_play_anim("skill", true)
		trigger_squash(1.14, 0.90)
		AudioManager.play_sfx("skill_wave", -3.0, 1.1 + level * 0.06)

		if dir == "down":
			# 向下派生：放置延时引爆的「小本本印记」陷阱法阵
			var mine_pos := Vector2(facing * (95.0 + level * 22.0), -26.0)
			_spawn_orb(mine_pos, Vector2.ZERO, 9 + level * 4, Vector2(facing * 320.0, -270.0), 18.0 + level * 4.0, 2.2, Color("#fde047") if level >= 3 else Color("#10b981"), "记小本本了!", true, 96.0 + level * 26.0)
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(0.0, -112.0), "小本本印记!", Color("#fde047"), 1.04)
		elif dir == "back":
			# 向后派生：优雅后撤瞬步 + 原地留雷
			if vfx:
				vfx.spawn_ghost(sprite, Color("#34d399"), 0.28)
				vfx.spawn_floating_text(global_position + Vector2(0.0, -112.0), "礼貌撤离!", Color("#6ee7b7"), 1.0)
			_spawn_orb(Vector2(0.0, -44.0), Vector2.ZERO, 8 + level * 3, Vector2(-facing * 260.0, -220.0), 16.0, 1.6, Color("#34d399"), "保持距离!", true, 92.0 + level * 20.0)
			global_position.x = clampf(global_position.x - facing * 125.0, 220.0, 1580.0)
			invincible_timer = maxf(invincible_timer, 0.2)
			AudioManager.play_sfx("dash", -4.0, 1.15)
		elif dir == "up":
			# 向上派生：对空扇形灵弹幕
			var count: int = 2 + level
			for i in range(count):
				var deg: float = -18.0 - float(i) * (44.0 / float(maxi(1, count - 1)))
				var ang: float = deg_to_rad(deg)
				var spd: float = 560.0 + level * 60.0
				_spawn_orb(Vector2(facing * 32.0, -64.0), Vector2(facing * cos(ang) * spd, sin(ang) * spd), 6 + level * 2, Vector2(facing * 220.0, -230.0), 15.0 + level * 2.0, 0.9, Color("#6ee7b7"), "洞察预判!" if i == 0 else "")
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(0.0, -112.0), "星辉对空阵!", Color("#6ee7b7"), 1.04)
		else:
			# 平射 / 前向：连发高速洞察灵弹
			var spd_mult: float = 1.22 if dir == "forward" else 1.0
			var orbs: int = level
			for i in range(orbs):
				var y_off: float = -56.0 + float(i - (orbs - 1) * 0.5) * 24.0
				_spawn_orb(Vector2(facing * (38.0 + i * 18.0), y_off), Vector2(facing * (600.0 + level * 70.0) * spd_mult, 0.0), 7 + level * 3, Vector2(facing * (250.0 + level * 55.0), -150.0), 16.0 + level * 3.0, 0.95, Color("#fde047") if level >= 3 else Color("#10b981"), "直觉贯通!" if i == 0 else "")
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(0.0, -112.0), "MAX·洞察连弹!" if level >= 3 else "洞察灵弹!", Color("#fde047") if level >= 3 else Color("#6ee7b7"), 1.05)
	else:
		# 共情吸收（I/5）：展开绿色共情法盾，期间受击免伤并转化为大量 EP
		skill2_cd = 6.2
		action_anim_state = "skill"
		action_anim_timer = 0.40
		_play_anim("skill", true)
		trigger_squash(0.90, 1.14)
		empathy_shield_timer = 1.5 + float(level) * 0.55
		AudioManager.play_sfx("aura_buff", -2.5, 1.05 + level * 0.05)
		if vfx:
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#34d399"), 16.0, 120.0 + level * 26.0, 0.34, 6.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -118.0), "共情吸收护盾!", Color("#4ade80"), 1.08)
		# 2/3 档蓄力释放时震退贴身敌人
		if level >= 2:
			var rad: float = 120.0 + level * 32.0
			for node in get_tree().get_nodes_in_group("fighters"):
				if node == self or not (node is BaseFighter):
					continue
				var target := node as BaseFighter
				if target.is_ko:
					continue
				if target.global_position.distance_to(global_position) <= rad:
					var push_d: float = signf(target.global_position.x - global_position.x)
					if push_d == 0.0:
						push_d = float(facing)
					target.take_damage(5 + level * 2, Vector2(push_d * 320.0, -200.0), self, false)

func take_damage(amount: int, knockback: Vector2, attacker: BaseFighter, is_ultimate: bool = false) -> void:
	# 共情吸收护盾核心机制：拦截非必杀伤害，免伤并转化为 2.2 倍 EP！
	if empathy_shield_timer > 0.0 and not is_ultimate and not is_ko:
		var gained_ep: float = minf(100.0 - ep, float(amount) * 2.2)
		ep = minf(100.0, ep + float(amount) * 2.2)
		AudioManager.play_sfx("charge_3", -2.0, 1.08)
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#4ade80"), 18.0, 116.0, 0.28, 6.0)
			vfx.spawn_hit_particles(global_position + Vector2(0.0, -48.0), Color("#fde047"), 14, 240.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -112.0), "共情吸收! +%d EP" % int(round(maxf(5.0, gained_ep))), Color("#4ade80"), 1.08)
		GameManager.trigger_hitstop(0.06)
		return
	super.take_damage(amount, knockback, attacker, is_ultimate)

func on_ultimate_cast() -> void:
	# Door Slam · 关门大吉：全屏特写 + 在对手位置召唤巨型翡翠符文石门拍飞并清空增益
	AudioManager.play_sfx("ult_cast", -1.0)
	invincible_timer = 0.9
	action_anim_state = "skill"
	action_anim_timer = 0.72
	_play_anim("skill", true)
	trigger_squash(0.88, 1.18)

	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.play_ult_cutin("INFJ", "DOOR SLAM · 关门大吉!!", GameManager.get_portrait_texture("infj"), Color("#10b981"), facing)
	GameManager.trigger_hitstop(0.22)

	var target_pos: Vector2 = global_position + Vector2(facing * 260.0, 0.0)
	for node in get_tree().get_nodes_in_group("fighters"):
		if node != self and node is BaseFighter and not (node as BaseFighter).is_ko:
			target_pos = (node as BaseFighter).global_position
			break

	var door := DoorSlamEffect.new()
	door.owner_fighter = self
	door.impact_pos = target_pos
	door.knockback_dir = signf(target_pos.x - global_position.x)
	if door.knockback_dir == 0.0:
		door.knockback_dir = float(facing)
	get_parent().add_child(door)

func _spawn_orb(offset_pos: Vector2, vel: Vector2, dmg: int, kb: Vector2, radius: float, life: float, col: Color, callout: String, is_mine: bool = false, exp_r: float = 96.0) -> void:
	var orb := MysticOrbProjectile.new()
	orb.owner_fighter = self
	orb.global_position = global_position + offset_pos
	orb.velocity = vel
	orb.damage = dmg
	orb.knockback = kb
	orb.orb_radius = radius
	orb.hit_radius = radius + 16.0
	orb.max_lifetime = life
	orb.tint_color = col
	orb.hit_callout = callout
	orb.is_mine = is_mine
	orb.explode_radius = exp_r
	get_parent().add_child(orb)

func _draw() -> void:
	super._draw()
	if empathy_shield_timer > 0.0 and not is_ko:
		var pulse: float = 0.5 + 0.5 * sin(_shield_pulse)
		var r: float = 54.0 + pulse * 6.0
		draw_circle(Vector2(0.0, -52.0), r, Color(0.12, 0.85, 0.58, 0.16 + pulse * 0.08))
		draw_arc(Vector2(0.0, -52.0), r, 0.0, TAU, 36, Color(0.35, 1.0, 0.72, 0.78), 4.0, true)
		draw_arc(Vector2(0.0, -52.0), r + 7.0, _shield_pulse * 0.5, _shield_pulse * 0.5 + PI * 1.35, 24, Color(0.99, 0.92, 0.42, 0.65), 2.5, true)
