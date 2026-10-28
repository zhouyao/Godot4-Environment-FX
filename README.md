# Godot Environment FX — 程序化 2D 雾特效方案

从原项目 `Misted` 中独立抽离的 **2D 环境遮蔽（雾）** 核心能力。
整套效果完全由着色器 + 节点逻辑程序化生成，**不依赖任何外部美术 / 贴图资源**，
可一键拷贝到任意 Godot 4.x（GL Compatibility）项目中复用，也可直接打开本工程运行演示。

---

## 一、项目简介

`fog 方案` 的核心是用一层或多层 **视差（Parallax）噪声着色** 在世界坐标空间里绘制「有机的、
会呼吸的」雾气，并支持：

- **区域限制**：雾只在指定矩形或椭圆区域内出现，区域外柔和渐隐（无可见硬边）。
- **多重视差景深**：单个节点即可叠加多层，近层移动快、远层移动慢，营造深度。
- **玩家触发淡入淡出**：角色进入 / 离开区域时，雾自动淡入 / 淡出。
- **实时可调**：浓度、覆盖率、柔边、颜色等参数全部作为导出属性，运行时改即生效。
- **前景 / 背景双用法**：通过调整 `draw_z` 既能盖住角色（前景迷雾），也能沉到最底层（氛围雾）。

---

## 二、核心能力 / 模块划分

| 模块 | 文件 | 职责 |
| --- | --- | --- |
| **Fog 控制器** | `addons/environment_fx/fog.gd` | 导出全部可调参数；管理多层视差、区域遮罩、玩家触发淡入淡出 |
| **Fog 预制体** | `addons/environment_fx/fog.tscn` | 4 个 `Parallax2D` 视差层 + `Area2D` 玩家检测区 + 程序化噪声纹理 |
| **Fog 着色器** | `addons/environment_fx/fog.gdshader` | 在世界坐标下用噪声等值线生成「云边」，并与区域包络相乘 |
| **插件入口** | `addons/environment_fx/plugin.*` | 让 addon 可在「项目设置 → 插件」中启用（无编辑器 UI） |

### 核心能力的边界（已剥离的依赖）

本方案**只依赖 Godot 内置节点与程序化噪声**（`Node2D` / `Parallax2D` / `ColorRect` /
`Area2D` / `CollisionShape2D` / `NoiseTexture2D` + `FastNoiseLite`），
**不依赖**原项目的以下部分，已全部剥离：

- 各类 autoload（`Globals` / `Inventory` / `Skills` / `Settings` …）
- `camera_director` 等编辑器插件与专属主题 / 本地化 / 美术资源
- 任何 `.png` / `.ogg` 等二进制素材（雾完全由噪声实时生成）

因此 `addons/environment_fx/` 目录可整体复制到其它工程直接使用。

---

## 三、目录结构

```
Godot4-FogFX-2D/
├── project.godot              # 独立 Godot 4.7 工程（GL Compatibility）
├── icon.svg
├── README.md                  # 本文档
├── LICENSE                    # MIT
├── addons/
│   └── environment_fx/        # ★ 核心能力（可整体拷贝复用）
│       ├── plugin.cfg
│       ├── plugin.gd
│       ├── fog.gd  fog.tscn  fog.gdshader
│       └── README.md          # addon 使用与参数速查
└── scenes/
    └── demo/                  # 能力演示（见第五节）
        ├── demo.tscn
        ├── demo_controller.gd  # 实时控制面板
        ├── player.gd  player.tscn
```

---

## 四、安装与运行

### 方式 A：直接运行本演示工程
1. 使用 **Godot 4.7+**（Renderer 选 GL Compatibility，本工程已配置）。
2. 用 Godot 打开 `Godot4-FogFX-2D/` 目录（即本仓库根）。
3. 按 <kbd>F5</kbd> 直接运行，主场景已设为 `scenes/demo/demo.tscn`。

### 方式 B：把能力接入你自己的工程
1. 把 `addons/environment_fx/` **整个目录** 复制到你的工程 `addons/` 下。
2. 在 Godot 编辑器中打开 **项目设置 → 插件**，启用 `Environment FX`（可选；不启用也能用）。
3. 在任意场景里「实例化」`fog.tscn`，或把 `Fog` 节点加进场景。
4. 在检查器里调节导出参数即可，无需写代码。

---

## 五、Demo 使用方式

演示场景 `scenes/demo/demo.tscn` 覆盖以下主要场景：

| 演示内容 | 对应节点 | 说明 |
| --- | --- | --- |
| 全屏氛围雾 | `FogAmbient` | `region_enabled=false`，铺在最底层做气氛 |
| 区域雾 + 玩家触发 | `FogZone` | 椭圆区域，角色走入才淡入；含 4 层视差景深 |

操作：
- **移动**：<kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> 或 **方向键**。
- **走进右侧雾区**：雾从 0 淡入到满；走出则淡出。
- **实时调参**：左上角控制面板可开关区域限制 / 椭圆包络 / 玩家触发，并拖动
  浓度、覆盖率、柔边，以及雾的颜色，所有改动即时生效。

---

## 六、公开接口（导出参数速查）

### `Fog`（`fog.gd`）
| 参数 | 类型 | 含义 |
| --- | --- | --- |
| `size` / `centered` | `Vector2` / `bool` | 区域尺寸与是否以节点原点为中心 |
| `region_enabled` | `bool` | 是否只在该区域内显示 |
| `region_fade` | `float` | 区域外柔和渐隐半宽（像素） |
| `elliptical` | `bool` | 椭圆包络（无直边直角）/ 矩形包络 |
| `cloud_noise_scale` | `float` | 云团尺度（越小云越大） |
| `coverage` | `float` | 覆盖率（越低越浓越连贯） |
| `softness` | `float` | 云边柔和度 |
| `edge_noise` | `float` | 区域边界的噪声扭曲幅度 |
| `density_variation` | `float` | 内部浓淡起伏 |
| `edge_margin` / `edge_gamma` | `float` | 平铺接缝渐隐 / 淡出曲线指数 |
| `density` / `thickness` | `float` | 整体浓度 / 厚度不透明度 |
| `fog_color` | `Color` | 雾的染色 |
| `activate_with_player` / `fade_duration` | `bool` / `float` | 玩家进入淡入、淡出时长 |
| `layer_scales` / `scroll_scale` | `Array[Vector2]` / `Vector2` | 多层视差倍率 / 整体视差倍率 |
| `draw_z` | `int` | 绘制层级（前景遮罩设大值，背景设负值） |
| 信号 | `player_entered` / `player_exited` | 玩家进入 / 离开区域时发出 |

---

## 七、开源许可

本项目以 **MIT License** 开源，详见 [`LICENSE`](./LICENSE)。
你可以自由使用、修改、分发，包括用于商业项目，仅需保留版权声明与许可声明。
