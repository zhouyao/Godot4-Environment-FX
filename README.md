# Godot Environment FX — 程序化 2D 雾 / 雨特效方案

从原项目 `Misted` 中独立抽离的 **2D 环境特效（雾 + 雨）** 核心能力。
整套效果完全由着色器 + 节点逻辑程序化生成，**不依赖任何外部美术 / 贴图 / 音频资源**，
可一键拷贝到任意 Godot 4.x（GL Compatibility）项目中复用，也可直接打开本工程运行演示。

---

## 一、项目简介

`environment_fx` 提供两个可互换的节点：

- **`Fog`（雾）**：用多层 **视差（Parallax）噪声着色** 在世界坐标空间绘制「有机的、会呼吸的」雾气。
- **`Rain`（雨）**：用程序化哈希在屏幕/世界空间生成下落雨丝，三层不同密度叠出景深。

二者共用同一套区域遮罩接口与导出参数（仅颜色属性名不同），都支持：

- **区域限制**：特效只在指定矩形或椭圆区域内出现，区域外柔和渐隐（无可见硬边）。
- **多重视差景深**：单个节点即可叠加多层，近层移动快、远层移动慢，营造深度。
- **玩家触发淡入淡出**：角色进入 / 离开区域时，特效自动淡入 / 淡出。
- **实时可调**：浓度、覆盖率、柔边、颜色等参数全部作为导出属性，运行时改即生效。
- **前景 / 背景双用法**：通过调整 `draw_z` 既能盖住角色（前景雨幕 / 迷雾），也能沉到最底层（氛围层）。

---

## 二、核心能力 / 模块划分

| 模块 | 文件 | 职责 |
| --- | --- | --- |
| **Fog 控制器** | `addons/environment_fx/fog.gd` | 导出全部可调参数；管理多层视差、区域遮罩、玩家触发淡入淡出 |
| **Fog 预制体** | `addons/environment_fx/fog.tscn` | 4 个 `Parallax2D` 视差层 + `Area2D` 玩家检测区 + 程序化噪声纹理 |
| **Fog 着色器** | `addons/environment_fx/fog.gdshader` | 在世界坐标下用噪声等值线生成「云边」，并与区域包络相乘 |
| **Rain 控制器** | `addons/environment_fx/rain.gd` | 与 `Fog` 相同的公开接口（`rain_color` 替代 `fog_color`） |
| **Rain 预制体** | `addons/environment_fx/rain.tscn` | 4 个 `Parallax2D` 视差层 + `Area2D` 玩家检测区 + 程序化噪声纹理 |
| **Rain 着色器** | `addons/environment_fx/rain.gdshader` | 纯哈希生成雨丝（64 / 128 / 192 列三层叠加），共用同一套区域遮罩 |
| **插件入口** | `addons/environment_fx/plugin.cfg` / `plugin.gd` | 让 addon 可在「项目设置 → 插件」中启用（无编辑器 UI） |

### 核心能力的边界（已剥离的依赖）

本方案**只依赖 Godot 内置节点与程序化噪声**（`Node2D` / `Parallax2D` / `ColorRect` /
`Area2D` / `CollisionShape2D` / `NoiseTexture2D` + `FastNoiseLite`），
**不依赖**原项目的以下部分，已全部剥离：

- 各类 autoload（`Globals` / `Inventory` / `Skills` / `Settings` …）
- `camera_director` 等编辑器插件与专属主题 / 本地化 / 美术资源
- 任何 `.png` / `.ogg` 等二进制素材（雾与雨均由噪声 / 哈希实时生成）

因此 `addons/environment_fx/` 目录可整体复制到其它工程直接使用。

---

## 三、目录结构

```
Godot4-FogFX-2D/
├── project.godot                 # 独立 Godot 4.7 工程（GL Compatibility）
├── main.tscn                     # 主场景：示例选择菜单（雾 / 雨）
├── icon.svg
├── README.md                     # 本文档
├── LICENSE                       # MIT
├── addons/
│   └── environment_fx/           # ★ 核心能力（可整体拷贝复用）
│       ├── plugin.cfg
│       ├── plugin.gd
│       ├── fog.gd  fog.tscn  fog.gdshader
│       ├── rain.gd  rain.tscn  rain.gdshader
│       └── README.md             # addon 使用与参数速查
└── scenes/
    ├── main_menu.gd              # 主菜单按钮 → 切换演示场景
    └── demo/                     # 能力演示（见第五节）
        ├── fog.tscn              # 雾效演示场景
        ├── fog_controller.gd     # 雾效实时控制面板
        ├── rain_demo.tscn        # 降雨演示场景
        ├── rain_controller.gd    # 降雨实时控制面板
        └── player.gd  player.tscn
```

---

## 四、安装与运行

### 方式 A：直接运行本演示工程
1. 使用 **Godot 4.7+**（Renderer 选 GL Compatibility，本工程已配置）。
2. 用 Godot 打开 `Godot4-FogFX-2D/` 目录（即本仓库根）。
3. 按 <kbd>F5</kbd> 直接运行，主场景为 `main.tscn`（示例选择菜单）。
4. 在菜单里点击「雾场景示例」或「雨场景示例」进入对应演示。

### 方式 B：把能力接入你自己的工程
1. 把 `addons/environment_fx/` **整个目录** 复制到你的工程 `addons/` 下。
2. 在 Godot 编辑器中打开 **项目设置 → 插件**，启用 `Environment FX`（可选；不启用也能用）。
3. 在任意场景里「实例化」`fog.tscn` 或 `rain.tscn`，或直接添加 `Fog` / `Rain` 节点。
4. 在检查器里调节导出参数即可，无需写代码。
5. 若要用「玩家进入淡入」，请让玩家节点加入 `"player"` 组（检测依据 `body.is_in_group("player")`）。

---

## 五、Demo 使用方式

主菜单 `main.tscn` 提供两个入口，分别对应：

| 演示场景 | 场景文件 | 内容 | 说明 |
| --- | --- | --- | --- |
| 雾场景示例 | `scenes/demo/fog.tscn` | `FogAmbient` / `FogZone` | 全屏氛围雾默认关闭；右侧椭圆雾区常驻，含 4 层视差景深 |
| 雨场景示例 | `scenes/demo/rain_demo.tscn` | `RainAmbient` / `RainZone` | 全屏氛围雨默认开启；右侧椭圆雨区常驻，含 4 层视差景深 |

两个场景的布局、控制面板与参数范围完全一致，只是特效类型不同：

- **氛围层**：`region_enabled = false`，铺在最底层（`draw_z = -5`）做气氛；面板可勾选开关并调节强度。
- **区域层**：椭圆区域、`region_enabled = true`、`draw_z = 100` 盖在角色之上；勾选「玩家进入淡入」后，
  角色走入才淡入到满，走出淡出。

操作：
- **移动**：<kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> 或 **方向键**。
- **走进右侧区域**：特效从 0 淡入到满（需先勾选「玩家进入淡入」）；走出则淡出。
- **实时调参**：左上角控制面板可开关氛围层 / 区域限制 / 椭圆包络 / 玩家触发，并拖动
  强度（`density`）、覆盖率（`coverage`）、柔边（`softness`）以及特效颜色，所有改动即时生效。
- **返回主菜单**：<kbd>Esc</kbd> 或点击右上角「返回主菜单」。

---

## 六、公开接口（导出参数速查）

`Fog`（`fog.gd`）与 `Rain`（`rain.gd`）的导出参数、默认值与范围完全一致，
只有颜色属性名不同：`Fog.fog_color` / `Rain.rain_color`。

| 参数 | 类型 | 含义 |
| --- | --- | --- |
| `size` / `centered` | `Vector2` / `bool` | 区域尺寸与是否以节点原点为中心 |
| `region_enabled` | `bool` | 是否只在该区域内显示 |
| `region_fade` | `float` | 区域外柔和渐隐半宽（像素） |
| `elliptical` | `bool` | 椭圆包络（无直边直角）/ 矩形包络 |
| `cloud_noise_scale` | `float` | 云团 / 雨势尺度（越小云团越大） |
| `coverage` | `float` | 雾：覆盖率（越低越浓越连贯）；雨：落雨列占比（0 = 无雨） |
| `softness` | `float` | 云边 / 雨丝柔和度 |
| `edge_noise` | `float` | 区域边界的噪声扭曲幅度 |
| `density_variation` | `float` | 内部浓淡起伏（雾团 / 阵雨） |
| `edge_margin` / `edge_gamma` | `float` | 平铺接缝渐隐 / 淡出曲线指数 |
| `density` | `float` | 整体浓度（雾）/ 强度（雨）（0~1） |
| `thickness` | `float` | 厚度不透明度（雾）/ 雨丝粗细实度（雨） |
| `fog_color` / `rain_color` | `Color` | 雾的染色（默认白）/ 雨的颜色（默认淡蓝） |
| `activate_with_player` / `fade_duration` | `bool` / `float` | 玩家进入淡入、淡出时长 |
| `layer_scales` / `scroll_scale` | `Array[Vector2]` / `Vector2` | 多层视差倍率 / 整体视差倍率 |
| `draw_z` | `int` | 绘制层级（前景遮罩设大值，背景设负值） |
| 信号 | `player_entered` / `player_exited` | 玩家进入 / 离开区域时发出 |

补充：

- 每个节点内含 4 个 `Parallax2D` 层，实际启用层数由 `layer_scales` 的长度决定（默认 1 层）。
- 雨的下落方向 / 风力由 `rain.gdshader` 的 `speed` uniform 控制（`x` 为风力，`y` 为下落速度，
  `(0, 1)` 为竖直下落），可在 `ColorRect` 的 `ShaderMaterial` 中用着色器参数微调；
  雾的漂移速度则对应 `fog.gdshader` 的 `speed` uniform。
- 材质设置了 `resource_local_to_scene`，并在运行时为多层拆分独立材质，多个实例之间不会串参数。

---

## 七、开源许可

本项目以 **MIT License** 开源，详见 [`LICENSE`](./LICENSE)。
你可以自由使用、修改、分发，包括用于商业项目，仅需保留版权声明与许可声明。
