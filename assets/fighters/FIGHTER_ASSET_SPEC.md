# Type Fighter · 角色 2D 像素动画资产需求与出图规范（ENFJ 标杆版）

> 本文档为全员 16 位 MBTI 角色的统一资产标杆（以 **ENFJ · 耀光剑士** 为模板）。
> 所有动作均按 **“循环动作丝滑（8 帧）+ 攻击动作狠脆（5～7 帧）+ 单组封顶 8 帧防 AI 变形”** 的高质感像素格斗标准设计。

---

## 一、全局美术与出图铁律（防踩坑必读）

1. **统一画风与精度**：16-bit 清晰像素风，1px 黑色像素外描边，零抗锯齿模糊，100% 忠实还原原版 16personalities 角色特征与配色。
2. **统一朝向**：除 `portrait.png` 和 `empathy_finish` 可正面/微侧外，**所有战斗动画一律 3/4 侧身朝右**（向左移动由 Godot 引擎自动水平镜像）。
3. **像素动画工具防“双人/裁头”铁律**：
   - 提示词中**严禁出现**“8×1 精灵表 / 横向排列 / 多格”字样（否则按帧生成的工具会在单帧内画出两个小人）。
   - 所有动作（含跳跃、冲刺、劈砍）一律 **原地居中做姿态（In-place）**，位移交由 Godot 引擎物理系统控制；头顶、头发、披风、武器尖端、靴底在每一帧内必须 **100% 完整留在画布边界内**，四周保留安全留边。
4. **持武器常识**：移动、跳跃、冲刺时单手自然将武器斜持于身侧或斜后方保持重心平衡，严禁直挺挺竖在身前挡腿。
5. **交付目录与命名**：
   - 立绘：`assets/fighters/<id>/concept/portrait.png`
   - 像素动画：`assets/fighters/<id>/frames/pixel_v1/<文件名>`（导出为单行横向透明 PNG，如 `8×1`、`6×1`、`5×1`）。

---

## 二、ENFJ 标杆全量图片需求总表（16 组核心 + 2 张投掷物 + 1 组可选彩蛋）

| 序号 | 分类 | 文件名 | 帧数 | 建议 FPS | 循环 | 核心用途 |
| :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| 01 | 静态立绘 | `concept/portrait.png` | 1 | - | - | 选人头像、大招全屏特写、KO 结算 |
| 02 | 基础移动 | `idle_sheet.png` | **8** | 8 | 是 | 待机呼吸与披风微摆（选人 & 战斗通用） |
| 03 | 基础移动 | `walk_sheet.png` | **8** | 12 | 是 | 经典 8 帧标准奔跑循环（彻底告别滑步） |
| 04 | 基础移动 | `jump_sheet.png` | **8** | 12 | 否 | 原地完整跳跃（1～2 起跳、3～6 滞空下落、7～8 落地） |
| 05 | 基础移动 | `dash_sheet.png` | **6** | 18 | 否 | 低身冲刺 / 闪避（`L` / `3`） |
| 06 | 防御受击 | `guard_sheet.png` | **4** | 6 | 是 | 持续格挡防御姿态（`S` / `↓`） |
| 07 | 防御受击 | `hit_sheet.png` | **4** | 14 | 否 | 受击吃痛后仰硬直（大幅提升打击反馈） |
| 08 | 轻击连招 | `light_1_sheet.png` | **5** | 16 | 否 | 轻击第 1 段：疾风横斩 |
| 09 | 轻击连招 | `light_2_sheet.png` | **5** | 16 | 否 | 轻击第 2 段：破晓上挑 |
| 10 | 轻击连招 | `light_3_sheet.png` | **6** | 16 | 否 | 轻击第 3 段：大跨步回旋收尾斩 |
| 11 | 重击招式 | `heavy_1_sheet.png` | **7** | 14 | 否 | 重击 1：高举蓄力砸地重劈 |
| 12 | 重击招式 | `heavy_2_sheet.png` | **7** | 14 | 否 | 重击 2：转身蓄力破晓大横扫 |
| 13 | 专属技能 | `skill1_sheet.png` | **8** | 16 | 否 | 技能 1（`U`/`4`）：三连剑气连续挥斩 |
| 14 | 专属技能 | `skill2_sheet.png` | **8** | 16 | 否 | 技能 2（`I`/`5`）：气焰共鸣举剑爆发 |
| 15 | 必杀大招 | `ultimate_sheet.png` | **8** | 12 | 否 | 必杀（`O`/`6`）：耀光破阵斩深蹲聚力斩 |
| 16 | 战败 KO | `ko_sheet.png` | **8** | 10 | 否 | 自身战败 KO：半跪驻剑（定格终帧） |
| 17 | 投掷物 | `projectile_skill1.png` | 1 | - | - | 技能 1 独立透明圆弧剑气（像素风） |
| 18 | 投掷物 | `projectile_ult.png` | 1 | - | - | 大招独立透明超大耀金斩波（像素风） |
| *可选* | 必杀彩蛋 | `empathy_finish_sheet.png` | **6** | 8 | 否 | 必杀击败对手后的专属送花终结演出 |

> **工作量总计**：15 组核心动画（**共 100 帧**）+ 3 张独立单帧图 = **18 组**（含可选终结演出为 19 组 / 106 帧）。

---

## 三、通用前缀块（每组出图必带）

在下方每组动作提示词前，均需固定拼接这段 **角色与构图锁死前缀**（做其他 15 个角色时，只需替换 `[CHAR]` 里的外貌描述即可）：

### 英文锁死前缀（推荐优先使用，像素动画工具识别最稳）
> `STRICTLY ONE SINGLE CHARACTER ONLY per frame, centered in-place inside the canvas with safe padding on all 4 sides (NEVER clip head, hair, cape, sword tip, or boots; NO multiple characters, NO sprite sheet grid, NO duplicate swords). Preserve 100% of the uploaded 16-bit pixel art ENFJ swordsman (crisp 1px black pixel outline, exact pixel density, dark charcoal shoulder-length hair, square charismatic face with smirk, yellow-green shoulder mantle, olive tunic with pale-green belt, teal sleeves and boots, deep olive cape, silver straight broadsword with round pommel). Facing 3/4 right.`

### 中文锁死前缀
> `严格仅绘制单个角色并居中原地做动作，四周保留安全边距（绝不裁切头顶、披风、剑尖或靴底；严禁多格排版、严禁分身、严禁双剑穿帮）。100% 保持参考图 16-bit 像素 ENFJ 剑士的像素精度、1px 黑色描边与全部造型特征（暗灰齐肩长直发、方脸微笑、黄绿肩饰、橄榄绿袍、浅绿腰带、青绿袖靴、深绿披风、银色圆柄直阔剑）。角色 3/4 侧身朝右。`

---

## 四、ENFJ 逐组动作提示词（直接复制拼接前缀即可）

### 02. 待机 `idle_sheet.png`（8 帧 · 循环）
- **EN**: `Smooth 8-frame looping battle idle animation. Relaxed athletic 3/4 stance, knees slightly bent, right hand holding the silver broadsword diagonally forward-down at the side (NOT blocking the legs), left hand ready. Subtle rhythmic breathing (chest rising and falling), hair and deep olive cape gently swaying in a light breeze, confident heroic posture.`
- **ZH**：`8 帧循环战斗待机动画。双脚微开呈自然战斗站姿，右手将银阔剑自然斜持于身侧前下方（不挡双腿），左手微抬。胸口有柔和的呼吸起伏，头发与深绿披风在微风中轻柔摆动，气场沉稳自信。`

### 03. 奔跑 `walk_sheet.png`（8 帧 · 循环）
- **EN**: `Smooth 8-frame looping athletic run cycle in-place. Torso leaning forward into the sprint, clear alternating stride with both legs passing through contact, down, passing, and high-knee push-off poses, left arm pumping naturally, right hand carrying the silver broadsword angled diagonally back behind the hip for balance, cape streaming horizontally backward in the wind.`
- **ZH**：`8 帧循环原地奔跑动画。上身前倾冲刺，双腿清晰交替迈步（触地→缓冲→跨步→蹬地高抬膝完整步态），左臂自然前后摆动，右手握银阔剑斜收于身后保持平衡，深绿披风在风中向后水平飘扬。`

### 04. 跳跃 `jump_sheet.png`（8 帧 · 原地一体）
- **EN**: `In-place 8-frame jump animation with natural sword-carrying mechanics (sword angled diagonally back/to the side, NEVER vertical in front of legs). Express jump strictly through posture without moving out of frame: crouch anticipation -> explosive push-off with front knee tucked up and cape whipping down -> mid-air athletic knee-tuck apex -> legs extending downward for landing with cape billowing high upward -> crouched landing squash -> smooth recovery stance.`
- **ZH**：`8 帧原地完整跳跃动画，符合人体常识持剑（右手将阔剑斜收身侧/身后保持平衡，绝不竖在身前挡腿）。仅通过原地姿态与披风表现跳跃：屈膝蓄力 → 蹬地收膝（披风下甩）→ 最高点团身滞空 → 下落伸腿备着陆（披风高高扬起）→ 落地屈膝缓冲 → 站稳复位。`

### 05. 冲刺 / 闪避 `dash_sheet.png`（6 帧）
- **EN**: `6-frame high-speed forward dash animation in-place. Sudden low aerodynamic crouch -> explosive forward lunge leaning sharply forward with back leg extended straight behind, sword swept horizontally backward, cape whipping flat behind -> crisp skidding brake back to balanced stance.`
- **ZH**：`6 帧高速前冲闪避动画（原地）。瞬间压低重心 → 极速前倾突进姿态（后腿向后蹬直、阔剑水平向后掠去、披风笔直向后拉平）→ 急停刹车稳住重心。`

### 06. 防御 `guard_sheet.png`（4 帧 · 循环）
- **EN**: `4-frame looping defensive guard stance. Solid braced low stance, knees bent, both hands firmly holding the silver broadsword vertically in front of the chest as a shield (blade pointing down or angled slightly up-forward), resolute determined expression, subtle cape flutter.`
- **ZH**：`4 帧循环防御格挡姿态。下盘稳扎微蹲，双手稳稳将银阔剑竖挡在胸前形成护盾，神情坚毅，披风随气流微微抖动。`

### 07. 受击硬直 `hit_sheet.png`（4 帧）
- **EN**: `4-frame hurt/hitstun recoil animation. Sudden knockback jolt from a frontal impact: torso snapping backward, head tilted back with grimacing eyes, arms and sword flung slightly outward off-balance, cape whipping forward-back -> recovering balance.`
- **ZH**：`4 帧受击硬直后仰动画。正面遭重击瞬间身体猛烈向后仰缩、闭眼皱眉吃痛、双手与大剑因失衡略微张开、披风甩动，随后努力稳住重心。`

### 08. 轻击 1 `light_1_sheet.png`（5 帧 · 疾风横斩）
- **EN**: `5-frame snappy horizontal sword slash (Light Attack 1). Quick windup pulling sword slightly back -> explosive horizontal right-to-left slash across chest with a bright emerald-green pixel motion smear arc -> crisp follow-through leaning forward -> quick recovery.`
- **ZH**：`5 帧利落横斩（轻击 1）。短促拉剑蓄势 → 极速横向挥斩并带出一道明亮翡翠绿像素刀光抹影 → 前倾收剑缓冲 → 快速回位。`

### 09. 轻击 2 `light_2_sheet.png`（5 帧 · 破晓上挑）
- **EN**: `5-frame rising upward diagonal slash (Light Attack 2). Low crouching drop with sword lowered -> explosive upward rising slash from low-back to high-front with a bright lime-emerald crescent pixel smear -> high follow-through -> smooth return.`
- **ZH**：`5 帧破晓上挑斩（轻击 2）。微蹲压低剑身 → 由下而上极速斜挑挥出亮绿像素弧形抹影 → 高举收招 → 回位。`

### 10. 轻击 3 `light_3_sheet.png`（6 帧 · 回旋重收尾斩）
- **EN**: `6-frame heroic finisher slash (Light Attack 3). Dynamic step-in windup turning shoulders back -> powerful wide diagonal cleave forward with a radiant golden-emerald pixel slash smear and cape whipping around -> strong forward lunge finish -> return to guard.`
- **ZH**：`6 帧轻连招收尾重斩（轻击 3）。上步转肩蓄势 → 大幅度斜劈斩出耀眼绿金色像素刀光、披风顺势甩开 → 前弓步定势 → 收招回位。`

### 11. 重击 1 `heavy_1_sheet.png`（7 帧 · 蓄力砸地重劈）
- **EN**: `7-frame heavy overhead ground-slam cleave (Heavy Attack 1). Pronounced 2-frame windup raising the silver broadsword high above the head with both hands -> explosive downward slam straight to the ground with a huge glowing lime-gold pixel slash arc and small ground energy burst -> heavy crouched impact hold -> lifting sword back to ready.`
- **ZH**：`7 帧蓄力重劈砸地（重击 1）。清晰 2 帧双手高举阔剑蓄力前摇 → 全力向下怒劈砸地，带出巨大绿金色像素劈砍弧光与地面微爆裂 → 低身定格震撼感 → 提剑收招。`

### 12. 重击 2 `heavy_2_sheet.png`（7 帧 · 破晓大横扫）
- **EN**: `7-frame heavy wide sweeping slash (Heavy Attack 2). Deep coiled twist pulling the broadsword far behind the back -> massive full-body horizontal sweep cutting wide forward with a thick luminous emerald-gold pixel arc smear -> dramatic wide-stance follow-through with cape flaring -> recovery.`
- **ZH**：`7 帧破晓蓄力大横扫（重击 2）。深沉转体将阔剑拉至身后蓄力 → 全身发力宽幅横扫，带出厚重耀金翡翠像素斩击弧 → 宽步收剑披风翻涌 → 回位。`

### 13. 技能 1 `skill1_sheet.png`（8 帧 · 三连剑气）
- **EN**: `8-frame heroic triple sword-wave casting animation. Braced heroic stance -> three rapid consecutive rhythmic sword slashes (diagonal down, diagonal up, wide horizontal) launching glowing emerald-gold crescent energy waves forward from the blade -> heroic follow-through.`
- **ZH**：`8 帧三连剑气释放动画。稳步立姿 → 连续三拍利落挥剑（斜下斩、斜上挑、宽幅横斩），每次挥剑都从剑刃前方荡出翡翠金能量弧光 → 帅气收招。`

### 14. 技能 2 `skill2_sheet.png`（8 帧 · 气焰共鸣）
- **EN**: `8-frame aura power-up burst animation. Brief crouch gathering energy -> raising the silver broadsword straight up toward the sky with glowing emerald-gold pixel aura flames erupting around his feet and cape billowing strongly upward -> radiant heroic battle stance.`
- **ZH**：`8 帧气焰共鸣爆发动画。短暂下蹲聚气 → 将银阔剑笔直高举向天，脚下与周身升腾起翡翠金色像素能量气焰、披风被气流高高吹起 → 昂扬战斗姿态。`

### 15. 必杀大招 `ultimate_sheet.png`（8 帧 · 耀光破阵斩）
- **EN**: `8-frame ultimate super attack animation. Dramatic low crouched charge holding the blazing golden-glowing broadsword back -> blinding heroic full-body forward mega-cleave unleashing a colossal golden-emerald radiant slash arc -> powerful triumphant follow-through pose with cape billowing dramatically.`
- **ZH**：`8 帧耀光破阵斩大招动画。极具张力的深蹲蓄力，银阔剑泛起耀眼金光向后拉满 → 全身爆发全力向前巨幅斩击，挥出磅礴耀金翡翠光弧 → 霸气收剑披风狂舞。`

### 16. 自身 KO `ko_sheet.png`（8 帧 · 半跪驻剑）
- **EN**: `8-frame non-looping defeat KO animation. Staggering backward from exhaustion -> dropping gracefully onto one knee -> planting the silver broadsword vertically into the ground in front of him with both hands resting on the pommel, head bowed respectfully, cape draped quietly to the floor (final frame holds this noble kneeling pose).`
- **ZH**：`8 帧非循环战败 KO 动画。力竭踉跄退半步 → 缓缓单膝跪地 → 将银阔剑竖直插在身前地面，双手搭在剑柄顶端微微低头，披风静静垂落地面（定格在终帧半跪驻剑姿势）。`

### 17 & 18. 独立像素投掷物（单帧透明 PNG）
- **`projectile_skill1.png`**：`Single isolated 16-bit pixel art glowing emerald-green and lime-gold hollow crescent sword-wave projectile facing right, sharp tapered tips, crisp pixel edges, NO character, pure white background (#FFFFFF).`
- **`projectile_ult.png`**：`Single isolated 16-bit pixel art colossal blazing golden-yellow and emerald radiant crescent ultimate sword-wave projectile facing right, dramatic faceted pixel energy streaks, sharp tapered tips, NO character, pure white background (#FFFFFF).`

### 可选彩蛋. 同理心送花终结 `empathy_finish_sheet.png`（6 帧）
- **EN**: `6-frame heartwarming victory finisher animation facing front-3/4 right. Sheathing/lowering his sword calmly -> smiling warmly and gracefully extending a bright golden-yellow pixel flower forward with his hand as a friendly gesture of empathy -> gentle cheerful pose with subtle pixel sparkles.`
- **ZH**：`6 帧同理心送花终结彩蛋动画（正面微侧）。从容收剑 → 露出温暖自信微笑，优雅地向前伸手递出一朵明亮的金黄色像素小花致意 → 温和定格并伴随细微像素星光。`

---

## 五、批量复用到其余 15 位 MBTI 角色的方法

其余 15 个角色（INTJ、INTP、ENTJ、ENTP、INFJ、INFP、ENFP、ISTJ、ISFJ、ESTJ、ESFJ、ISTP、ISFP、ESTP、ESFP）直接复用上述 **16 组核心框架（总计 100 帧）**，只需：
1. 将「通用前缀块」里的 ENFJ 外貌与武器描述替换成对应角色（如 `INTJ` 的紫色棋子/魔杖、`ISFP` 的画笔调色板、`ENFP` 的彩虹礼花筒等）；
2. 将 `light_1~3`、`heavy_1~2`、`skill1/2`、`ultimate`、`ko` 中的“挥剑”替换为该角色的专属武器动作即可；
3. 生成后放进 `assets/fighters/<id>/frames/pixel_v1/`，在 [GameManager.gd](file:///Users/Admin/Desktop/MBTI-Brawl-Godot/scripts/GameManager.gd) 登记后即可自动在 Godot 战斗与选人舞台生效。
