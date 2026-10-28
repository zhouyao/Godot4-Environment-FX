# Environment FX（addon）

Godot 4.x 程序化 2D 雾特效。本目录可整体复制到任意工程的 `addons/` 下使用。

## 包含内容
- `fog.gd` / `fog.tscn` / `fog.gdshader` —— 雾
- `plugin.cfg` / `plugin.gd` —— 插件入口（无编辑器 UI）

## 快速接入
1. 复制本目录到你的工程 `addons/environment_fx/`。
2. 项目设置 → 插件 → 启用 `Environment FX`（可选）。
3. 实例化 `fog.tscn`，或在场景里添加 `Fog` 节点。
4. 在检查器调节导出参数即可。

## 关键参数（Fog）
`size`、`region_enabled`、`region_fade`、`elliptical`、`cloud_noise_scale`、
`coverage`、`softness`、`edge_noise`、`density_variation`、`edge_margin`、
`edge_gamma`、`density`、`thickness`、`fog_color`、`activate_with_player`、
`fade_duration`、`layer_scales`、`scroll_scale`、`draw_z`。

## 依赖边界
仅依赖 Godot 内置节点与程序化噪声（`NoiseTexture2D` + `FastNoiseLite`），
**无需任何外部贴图 / 音频资源**。角色检测通过 `body.is_in_group("player")` 实现，
请让你的玩家节点加入 `"player"` 组。
