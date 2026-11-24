# INFJ（提倡者 · 绿老头）全套 16-bit 像素美术需求与提示词手册

> 交付目录：`assets/fighters/infj/frames/pixel_v1/`
> 总计：**21 组**（15 组角色动作共 100 帧 + 6 组独立法球与技能特效素材）。
> 使用像素动画生成工具时，请上传 **INFJ 像素版基础形象**作为参考图，并把下方「锁死前缀」与对应组别动作提示词拼接使用。

---

## 一、INFJ 角色全量需求总表（21 组）

### A. 角色本体动作（15 组 · 共 100 帧）

| 序号 | 文件名 | 帧数 | FPS | 循环 | 动作定位 |
| :---: | :--- | :---: | :---: | :---: | :--- |
| 01 | `idle_sheet.png` | 8 | 8 | 是 | 沉稳长者待机呼吸，长白胡须与绿法袍轻摆 |
| 02 | `walk_sheet.png` | 8 | 12 | 是 | 提袍轻快奔跑循环，法杖斜持身侧 |
| 03 | `jump_sheet.png` | 8 | 12 | 否 | 原地完整跳跃（起跳→滞空→下落→落地） |
| 04 | `dash_sheet.png` | 6 | 18 | 否 | 灵能前倾滑步闪现，银发法袍向后拉平 |
| 05 | `guard_sheet.png` | 4 | 6 | 是 | 竖杖闭目冥想防御姿态 |
| 06 | `hit_sheet.png` | 4 | 14 | 否 | 受击吃痛后仰、白胡须与法杖甩动 |
| 07 | `light_1_sheet.png` | 5 | 16 | 否 | 轻击 1（礼貌微笑）：单手轻点法杖发球 |
| 08 | `light_2_sheet.png` | 5 | 16 | 否 | 轻击 2：反手优雅横挥法杖施法 |
| 09 | `light_3_sheet.png` | 6 | 16 | 否 | 轻击 3（双连灵球）：双手前推法杖连发 |
| 10 | `heavy_1_sheet.png` | 7 | 14 | 否 | 重击 1（灵魂震慑）：高举法杖猛顿地面 |
| 11 | `heavy_2_sheet.png` | 7 | 14 | 否 | 重击 2（看穿你了）：蓄力前指发射高能洞察球 |
| 12 | `skill1_sheet.png` | 8 | 16 | 否 | 技能 1（洞察预言）：法杖画圆蓄力连射/布阵 |
| 13 | `skill2_sheet.png` | 8 | 16 | 否 | 技能 2（共情吸收）：横杖胸前展开共情法盾 |
| 14 | `ultimate_sheet.png` | 8 | 12 | 否 | 大招（Door Slam）：高举法杖召唤天门→挥臂下压关门 |
| 15 | `ko_sheet.png` | 8 | 10 | 否 | 战败 KO：叹气坐地、法杖斜靠身旁（定格终帧） |

### B. 专属投掷物与攻击特效（6 组 · 独立透明像素素材，不含人物）

| 序号 | 文件名 | 帧数 | FPS | 循环 | 对应代码模块与用途 |
| :---: | :--- | :---: | :---: | :---: | :--- |
| 16 | `vfx_orb_light.png` | 4 | 14 | 是 | 轻击 / 技能 1 通用：**翡翠灵球**（带光晕与小拖尾） |
| 17 | `vfx_orb_heavy.png` | 4 | 14 | 是 | 重击 2 / 满蓄技能 1：**高能洞察灵球**（青金色漩涡 + 洞察之眼符文） |
| 18 | `vfx_rune_mine.png` | 4 | 10 | 是 | 技能 1 下/后派生：**「小本本印记」地面符文陷阱** |
| 19 | `vfx_soul_blast.png` | 6 | 18 | 否 | 重击 1 & 陷阱引爆：**灵魂震慑冲击爆发**（冲天翡翠光柱 + 符文环） |
| 20 | `vfx_empathy_shield.png` | 4 | 10 | 是 | 技能 2：**共情吸收球形翡翠符文法盾**（叠在人物外圈） |
| 21 | `vfx_door_slam.png` | 6 | 14 | 否 | 大招：**Door Slam 巨型翡翠符文双开石门**（张开→猛然闭合砸地爆发） |

---

## 二、角色动画通用锁死前缀（01～15 组必带）

### English Prefix（推荐优先使用）
> `STRICTLY ONE SINGLE CHARACTER ONLY per frame, centered in-place inside the canvas with safe margin on all 4 sides (NEVER clip head, hair, beard, robe, wand tip, or boots; NO multiple characters, NO sprite sheet grid, NO duplicate wands). Preserve 100% of the uploaded 16-bit pixel art INFJ sage wizard (crisp 1px black pixel outline, exact pixel density, flowing light-silver wavy long hair, long tied white-silver beard with a tiny dark-green tie band near the tip, calm wise eyes with grey eyebrows, emerald-olive wizard robe with wide sleeves, mint-teal V-collar and dark-teal hem trim, teal pointed boots, holding a slender crooked dark-emerald mystic wand). Facing 3/4 right.`

### 中文锁死前缀
> `严格仅绘制单个角色并居中原地做动作，四周保留安全边距（绝不裁切头顶、银发、长胡须、法袍、杖尖或靴底；严禁多格排版、严禁分身、严禁双法杖穿帮）。100% 保持参考图 16-bit 像素 INFJ 绿老头智者的像素精度、1px 黑色描边与全部造型特征（银灰波浪长发、末端系绿带的白色长胡须、温和深邃眼神与灰眉、宽袖橄榄绿长袍、青绿 V 领与深青镶边、青绿尖头靴、手持纤细弯曲深绿法杖）。角色 3/4 侧身朝右。`

---

## 三、角色本体逐组提示词（01～15）

### 01. 待机 `idle_sheet.png`（8 帧 · 循环）
- **EN**: `Smooth 8-frame looping mystic sage idle animation. Calm poised 3/4 stance, right hand holding the slender green wand naturally at the side-front with a subtle faint emerald sparkle at the tip, left hand relaxed. Gentle breathing, long white beard and silver hair swaying softly, wizard robe hem fluttering lightly.`
- **ZH**：`8 帧循环智者待机动画。沉稳 3/4 站姿，右手自然将弯曲绿法杖轻持于身侧前方（杖尖带微弱翡翠星光），左手自然垂放。柔和呼吸起伏，长白胡须、银发与长袍下摆随微风轻柔摆动。`

### 02. 奔跑 `walk_sheet.png`（8 帧 · 循环）
- **EN**: `Smooth 8-frame looping brisk wizard run cycle in-place. Slight forward lean, lively alternating steps lifting the teal boots cleanly beneath the flowing green robe hem, left arm swinging for balance, right hand holding the green wand angled diagonally back-side, long silver hair and white beard streaming gently behind.`
- **ZH**：`8 帧循环原地轻快奔跑动画。微前倾提袍快跑，青绿靴子在绿袍下摆间清晰交替迈步，左臂自然摆动，右手握法杖斜收于身侧后方保持平衡，银色长发与长白胡须随跑动向后轻飘。`

### 03. 跳跃 `jump_sheet.png`（8 帧 · 原地一体）
- **EN**: `In-place 8-frame wizard jump animation with natural anatomy (wand held angled diagonally back-side for balance, NEVER stiffly vertical in front). Express jump purely through in-place posture without leaving the frame: springy knee crouch -> upward push-off with front knee lifted and robe hem sweeping down -> mid-air knee tuck with robe floating -> legs extending downward for landing while silver hair, beard, and wide robe sleeves billow upward -> crouched landing squash -> calm recovery stance.`
- **ZH**：`8 帧原地完整跳跃动画，符合人体常识持杖（法杖斜收身侧后方保持平衡，绝不直竖身前）。仅通过原地姿态与衣摆飘动表现跳跃：屈膝蓄力 → 蹬地收膝（袍摆下甩）→ 最高点团身滞空 → 下落伸腿准备着陆（银发、胡须与宽袖袍摆向上飘起）→ 落地屈膝缓冲 → 站稳复位。`

### 04. 冲刺 / 闪避 `dash_sheet.png`（6 帧）
- **EN**: `6-frame mystic glide-dash animation in-place. Low aerodynamic forward glide leaning sharply forward, feet skimming cleanly, emerald robe, wide sleeves, silver hair, and white beard streaming horizontally backward, wand trailing behind with a bright mint-emerald glow -> graceful upright brake.`
- **ZH**：`6 帧灵能滑步闪避动画（原地）。低身极速前倾滑行，绿袍、宽袖、银发与白胡须笔直向后拉平，法杖拖于身后并闪耀青绿灵光 → 优雅急停站稳。`

### 05. 防御 `guard_sheet.png`（4 帧 · 循环）
- **EN**: `4-frame looping meditative guard stance. Grounded braced stance, eyes calmly closed, holding the green wand vertically in front of the chest with both hands as a mystic ward, faint emerald energy shimmer along the wand, gentle beard sway.`
- **ZH**：`4 帧循环冥想防御姿态。稳扎站姿，微闭双眼，双手将绿法杖竖举于胸前作为灵能屏障，杖身泛起柔和翡翠微光，胡须轻微晃动。`

### 06. 受击硬直 `hit_sheet.png`（4 帧）
- **EN**: `4-frame hurt/hitstun recoil animation. Startled knockback jolt from a frontal hit: torso snapping backward, eyes squeezed shut in shock, arms and green wand flung outward off-balance, long white beard and silver hair whipping back -> steadying balance.`
- **ZH**：`4 帧受击硬直后仰动画。正面受击瞬间惊愕后仰、闭眼吃痛、双手与法杖失衡张开、长白胡须与银发向后甩起 → 稳住重心。`

### 07. 轻击 1 `light_1_sheet.png`（5 帧 · 礼貌微笑发球）
- **EN**: `5-frame snappy wand-cast animation (Light Attack 1). Brief graceful pull-back of the wand arm -> crisp forward flick pointing the green wand straight right, releasing a tiny bright emerald pixel spark flash from the wand tip with a polite calm smile -> smooth return.`
- **ZH**：`5 帧利落施法（轻击 1·礼貌微笑）。法杖微收蓄势 → 单手向前轻快点出绿法杖，杖尖迸发一点明亮翡翠像素星光，面带温和微笑 → 顺滑收手。`

### 08. 轻击 2 `light_2_sheet.png`（5 帧 · 反手横挥施法）
- **EN**: `5-frame elegant backhand wand sweep (Light Attack 2). Slight torso twist pulling the wand across the chest -> swift outward horizontal backhand flick tracing a thin glowing mint-green pixel magic ribbon in front -> poised follow-through.`
- **ZH**：`5 帧反手优雅横挥施法（轻击 2）。微转肩将法杖收至胸前 → 反手向外利落横挥，带出一道细长薄荷绿像素灵能光丝 → 从容收招。`

### 09. 轻击 3 `light_3_sheet.png`（6 帧 · 双连灵球推掌）
- **EN**: `6-frame decisive double-orb cast finisher (Light Attack 3). Dynamic step-in gathering emerald light between both hands and the wand -> thrusting both hands and wand forward together in a burst of bright emerald-gold pixel magic sparks, robe sleeves billowing back -> recovery.`
- **ZH**：`6 帧双连灵球收尾施法（轻击 3）。上步双手与法杖在胸前汇聚翡翠灵光 → 双手同法杖猛然向前推出，迸发耀眼绿金像素星火、宽袖向后翻卷 → 收招回位。`

### 10. 重击 1 `heavy_1_sheet.png`（7 帧 · 灵魂震慑顿地）
- **EN**: `7-frame heavy ground-slam spell (Heavy Attack 1). Clear 2-frame windup raising the glowing green wand high overhead -> slamming the wand tip sharply downward toward the ground in front, triggering a bright emerald pixel shock spark at his feet, beard and hair bouncing from impact -> dignified lift back to stance.`
- **ZH**：`7 帧高举法杖顿地重击（重击 1·灵魂震慑）。清晰 2 帧高举发光法杖前摇 → 猛力将杖尖砸向身前地面，脚边迸发强烈翡翠像素震波火星、银发胡须随震动弹起 → 稳重抬杖复位。`

### 11. 重击 2 `heavy_2_sheet.png`（7 帧 · 看穿你了高能法球）
- **EN**: `7-frame charged piercing-gaze cast (Heavy Attack 2). Focused 2-frame charge leaning back with eyes glowing bright teal and wand tip blazing emerald-gold -> snapping forward pointing the wand intensely straight ahead with a sharp burst of teal-gold magic light -> calm recoil recovery.`
- **ZH**：`7 帧蓄力洞察光球施法（重击 2·看穿你了）。专注 2 帧后仰蓄力、双眼泛起青绿微光、杖尖凝聚绿金强光 → 身体前倾直指前方猛然释放青金爆裂灵光 → 平稳收招。`

### 12. 技能 1 `skill1_sheet.png`（8 帧 · 洞察预言连射）
- **EN**: `8-frame mystic prophecy spellcasting animation. Swirling the green wand in a glowing emerald circular arc in front of him to draw a rune -> three rapid rhythmic forward thrusts launching emerald magic energy pulses, silver hair and robe swirling with mystic wind -> graceful finish.`
- **ZH**：`8 帧洞察预言施法动画。手持绿法杖在身前凌空画圆勾勒发光翡翠符文 → 连续三拍灵巧前指释放灵能脉冲，银发与绿袍随灵风翻涌 → 优雅收势。`

### 13. 技能 2 `skill2_sheet.png`（8 帧 · 共情吸收展开护盾）
- **EN**: `8-frame empathy barrier casting animation. Calm inward breath bringing the wand horizontally across his chest -> spreading both arms smoothly outward in a serene benevolent pose as soft luminous emerald-gold sparkles radiate around his body and robe floats gently -> tranquil shielded stance.`
- **ZH**：`8 帧共情吸收护盾展开动画。平静吸气将法杖横抱胸前 → 双臂慈和而沉稳地向两侧舒展，周身泛起柔和翡翠金像素微光、衣摆轻浮 → 宁静护盾姿态。`

### 14. 必杀大招 `ultimate_sheet.png`（8 帧 · Door Slam 关门大吉）
- **EN**: `8-frame dramatic ultimate casting animation (Door Slam). Deep solemn windup raising both hands and the blazing emerald-gold wand skyward as wind whips his silver hair and long white beard upward -> fierce decisive downward double-arm slam motion commanding a giant unseen door to shut with an intense emerald-gold flash -> stern composed finish.`
- **ZH**：`8 帧必杀大招施法动画（Door Slam 关门大吉）。庄严蓄力，双手高举耀眼绿金法杖直指苍穹，狂风将银发与白胡须高高吹起 → 神情骤然决绝，双臂猛力向下狠压做出“重重关门”的手势并伴随剧烈绿金闪光 → 肃穆收势。`

### 15. 自身 KO `ko_sheet.png`（8 帧 · 叹气坐地）
- **EN**: `8-frame non-looping defeat KO animation. Staggering backward with a weary sigh -> gently sinking down to sit cross-legged / on one knee on the ground, resting his forehead softly on one hand in quiet disappointment while his green wand lies beside him and his white beard drapes down (final frame holds this calm defeated pose).`
- **ZH**：`8 帧非循环战败 KO 动画。无奈踉跄后退叹气 → 缓缓跌坐/单膝落座地面，一手轻扶额头露出“算了累了”的平静失落神情，绿法杖斜靠身旁、白胡须垂落地面（定格终帧）。`

---

## 四、专属法球与技能特效逐组提示词（16～21，全部不含人物）

> **特效通用前缀**：`16-bit pixel art game VFX sprite ONLY, NO character, NO human, centered inside the canvas with generous transparent/pure white padding on all 4 sides, crisp sharp pixel edges with luminous emerald-teal and golden highlights, zero blurry anti-aliasing.`

### 16. 翡翠灵球 `vfx_orb_light.png`（4 帧 · 循环）
- **EN**: `[特效通用前缀] 4-frame looping glowing emerald-green mystic magic orb projectile facing right. Bright white-mint core, swirling emerald pixel energy aura, small sparkling pixel trail drifting slightly left.`
- **ZH**：`16-bit 像素风独立特效（无人物）。4 帧循环朝右飞行的翡翠绿灵能法球：亮白薄荷核心、旋转的翡翠像素能量外环，左侧带细碎像素星光拖尾。`

### 17. 高能洞察灵球 `vfx_orb_heavy.png`（4 帧 · 循环）
- **EN**: `[特效通用前缀] 4-frame looping large high-powered teal-and-gold psychic insight orb projectile facing right. Intense swirling emerald-teal plasma vortex with a subtle glowing golden mystic eye rune pulsing at its center and crackling pixel sparks.`
- **ZH**：`16-bit 像素风独立特效（无人物）。4 帧循环朝右飞行的大型青金色高能洞察法球：强烈旋转的青绿灵能漩涡，核心隐约浮现发光金色“洞察之眼”神秘符文与噼啪像素电光。`

### 18. 小本本印记陷阱 `vfx_rune_mine.png`（4 帧 · 循环）
- **EN**: `[特效通用前缀] 4-frame looping floating mystic emerald-gold rune trap seal. Glowing geometric pixel magic circle pulsing gently with floating emerald diamond shards and a tiny glowing golden ledger/quill rune symbol in the center.`
- **ZH**：`16-bit 像素风独立特效（无人物）。4 帧循环悬浮旋转的翡翠金色神秘符文陷阱印记：柔和脉动的像素魔法阵、漂浮翡翠菱形碎晶，中心带微光金色小符文徽记。`

### 19. 灵魂震慑爆发 `vfx_soul_blast.png`（6 帧 · 非循环）
- **EN**: `[特效通用前缀] 6-frame explosive emerald psychic shockwave pillar VFX erupting upward from a ground rune ring. Starts with a bright flash on the floor -> towering surge of emerald-teal and golden pixel light beams and shards -> dissipating into glowing pixel sparkles.`
- **ZH**：`16-bit 像素风独立特效（无人物）。6 帧灵魂震慑爆发特效：地面符文环瞬间强闪 → 冲天而起的翡翠青金像素灵能光柱与迸裂晶芒 → 化为飘散的像素星尘消散。`

### 20. 共情吸收护盾 `vfx_empathy_shield.png`（4 帧 · 循环）
- **EN**: `[特效通用前缀] 4-frame looping translucent spherical emerald-green and soft gold mystic barrier aura ring. Hollow glowing pixel magic dome with delicate geometric hex/rune highlights shimmering around the rim, transparent center so a character can stand inside it.`
- **ZH**：`16-bit 像素风独立特效（无人物）。4 帧循环半透明球形翡翠金共情法盾：外缘闪烁精细像素六边形/符文光泽，中心通透留空（用于罩在角色外围）。`

### 21. 巨型翡翠石门 `vfx_door_slam.png`（6 帧 · 非循环）
- **EN**: `[特效通用前缀] 6-frame colossal mystical emerald-stone double doors VFX ("Door Slam" ultimate). Ornate ancient carved emerald-green stone double doors inlaid with glowing golden geometric runes: Frame 1-2 doors materialize wide open -> Frame 3-4 slamming violently shut with blinding emerald-gold impact sparks and shockwave dust at the base -> Frame 5-6 sealed shut pulsing with golden lock runes.`
- **ZH**：`16-bit 像素风独立特效（无人物）。6 帧巨型翡翠符文双开古石门大招特效（Door Slam）：精雕深绿翡翠巨门镶嵌发光金色几何符文——第 1～2 帧双门大开显现 → 第 3～4 帧猛然轰隆闭合、门缝与底部炸出耀眼绿金像素冲击火花与气浪 → 第 5～6 帧紧闭封印并闪烁金色符文。`
