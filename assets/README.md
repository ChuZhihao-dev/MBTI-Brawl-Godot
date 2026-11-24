# 静态资源目录规范 (`assets/`)

用于存放各个 MBTI 角色的原画设计与动作帧序列（按角色分目录，避免双人开发合并冲突）。

## 目录结构

```text
assets/
└── fighters/
    ├── intj/
    │   ├── concept/   # 原画设计稿（立绘、设定图、选人头像等）
    │   └── frames/    # 游戏内动作帧 / 精灵图（PNG 透明背景）
    ├── infj/
    │   ├── concept/
    │   └── frames/
    ├── entp/
    │   ├── concept/
    │   └── frames/
    └── enfp/
        ├── concept/
        └── frames/
```

## 推荐命名规范

* **原画设计 (`concept/`)**：
  * `portrait.png`（选人卡片头像/半身像）
  * `sheet.png`（角色三视图/设定稿）
* **动作帧 (`frames/`)**：统一使用 `动作名_两位序号.png`（透明背景 PNG，建议角色统一朝右，引擎会自动镜像翻转）：
  * 待机：`idle_01.png`, `idle_02.png` ...
  * 移动：`walk_01.png`, `walk_02.png` ...
  * 跳跃：`jump_01.png`
  * 普攻：`attack_01.png`, `attack_02.png` ...
  * 特技：`skill_01.png` ...
  * 大招：`ult_01.png` ...
  * 受击：`hit_01.png`
  * 特殊状态（如 ENFP 电量耗尽）：`exhausted_01.png`
