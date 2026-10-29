shader_type canvas_item;

// —— 降雨表现：程序化生成的下落雨丝（无外部贴图，纯噪声/哈希） ——
// 与 fog.gdshader 保持一致的区域遮罩接口，可无缝替换。

// 雨的颜色（可在 Rain 节点的 rain_color 中配置）
uniform vec3 rain_color = vec3(0.72, 0.82, 1.0);
// 雨的整体强度（0~1）。所有层共用，统一控制。
uniform float density: hint_range(0.0, 1.0) = 0.25;
// 下落方向 × 速度（x 分量为风力，默认竖直下落）
uniform vec2 speed = vec2(0.0, 1.0);
// 雨丝的"实度 / 粗细"（0~1）：越大雨丝越粗越实
uniform float thickness: hint_range(0.0, 1.0) = 0.85;
// 覆盖率：落雨的列占比（0 = 无雨，1 = 全部列落雨）
uniform float coverage: hint_range(0.0, 1.0) = 0.18;
// 雨丝柔边：越大雨丝边缘越朦胧
uniform float softness: hint_range(0.01, 1.0) = 0.2;

// 区域限制：region_enabled = false 时行为与无区域一致
uniform bool region_enabled = false;
uniform vec2 region_min = vec2(0.0);
uniform vec2 region_max = vec2(0.0);
// 区域包络衰减半宽（像素）：只负责"区域外逐渐消失"，很宽很柔，不构成可见轮廓
uniform float region_fade = 400.0;
// true = 椭圆包络（没有直边和直角），false = 矩形包络
uniform bool elliptical = false;

// 区域强度起伏：让雨不是均匀一片（对应 Fog 的 density_variation）
uniform sampler2D mask_noise_texture: repeat_enable, filter_linear;
uniform float cloud_noise_scale: hint_range(0.0002, 0.01) = 0.0016;
// 用噪声扭曲"区域包络"的边界，让包络轮廓本身也不是直线/直角
uniform float edge_noise: hint_range(0.0, 1200.0) = 320.0;
// 各层不同采样偏移：各层雨形不同，叠出层次
uniform float edge_seed = 0.0;
// 内部浓淡起伏：让雨不是一片死白
uniform float density_variation: hint_range(0.0, 1.0) = 0.3;
// 几何边缘渐隐（UV 比例 0~0.5）：把 ColorRect / Parallax 平铺接缝的硬边抹掉
uniform float edge_margin: hint_range(0.0, 0.5) = 0.04;
// 淡出曲线指数
uniform float edge_gamma: hint_range(0.5, 4.0) = 1.0;

varying vec2 world_pos;

// 均匀哈希：取代噪声贴图，生成每列雨丝的随机参数
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float smoother_step(float e0, float e1, float x) {
	float t = clamp((x - e0) / max(e1 - e0, 0.0001), 0.0, 1.0);
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 噪声原始值是钟形分布（集中在 0.5 附近），拉开对比度才能真正推动边界
float stretch(float v) {
	return clamp((v - 0.5) * 3.0 + 0.5, 0.0, 1.0);
}

// 一层雨：在 UV 空间（每平铺块 0~1）生成向下滑落的雨丝。
// 列数 / 纵向周期取整数，且随机参数只依赖"列"而非"行"，
// 因此跨 Parallax2D 平铺块天然无缝（与雾的 UV 平铺策略一致）。
float rain_layer(vec2 uv, float columns, float period, float t, float seed) {
	float colf = uv.x * columns;
	float col = floor(colf);
	float fx = fract(colf);

	// 该列是否落雨：coverage 越大，落雨的列越多
	float rnd = hash21(vec2(col, seed));
	if (rnd > coverage) {
		return 0.0;
	}

	// 雨丝在列内的水平位置（居中 ±0.35，不会跨到相邻列）
	float xoff = (hash21(vec2(col, seed + 11.3)) - 0.5) * 0.7;
	float dx = abs(fx - (0.5 + xoff));
	// 雨丝半宽：thickness 越大越粗（0.008~0.05 列宽）
	float halfw = mix(0.008, 0.05, thickness);
	float edge = max(softness * 0.06, 0.001);
	float line = 1.0 - smoothstep(halfw, halfw + edge, dx);

	// 每条雨丝的长度与下落相位（只依赖列，保证纵向无缝）
	float len = mix(0.25, 0.9, hash21(vec2(col, seed + 5.7)));
	float phase = hash21(vec2(col, seed + 2.9));
	float fall = 0.6 + rnd * 0.8;
	float fy = fract(uv.y * period - t * fall + phase);
	// fy 接近 len 的一端逐渐变淡 = 雨丝尾迹
	float fade = mix(0.05, 0.3, thickness);
	float drop = 1.0 - smoothstep(len - fade, len, fy);

	// 内部浓淡起伏：让雨不是均匀一片
	float dv = mix(1.0 - density_variation, 1.0, hash21(vec2(col, seed + 9.1)));

	return line * drop * dv;
}

void vertex() {
	// MODEL_MATRIX: 局部 -> 世界；已包含 Parallax2D 的滚动偏移与 repeat 平铺偏移
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// wind: speed.x 让雨丝整体倾斜（默认 0，竖直下落）
	float tilt = clamp(speed.x, -1.0, 1.0) * 0.4;
	vec2 uv = vec2(UV.x + UV.y * tilt, UV.y);

	float t = TIME * (0.5 + length(speed));
	// 三层不同密度的雨丝叠出景深（近处更粗更亮、远处更细更淡）
	float rain = 0.0;
	rain += rain_layer(uv, 64.0, 10.0, t, edge_seed) * 0.55;
	rain += rain_layer(uv, 128.0, 16.0, t * 1.3, edge_seed + 17.0) * 1.0;
	rain += rain_layer(uv, 192.0, 22.0, t * 1.7, edge_seed + 41.0) * 0.5;

	float mask = 1.0;

	if (region_enabled) {
		// 1) 区域有符号距离场（像素，区域内为正）
		float sdf;
		if (elliptical) {
			vec2 center = (region_min + region_max) * 0.5;
			vec2 half_size = max((region_max - region_min) * 0.5, vec2(1.0));
			sdf = (1.0 - length((world_pos - center) / half_size)) * min(half_size.x, half_size.y);
		} else {
			vec2 dmin = world_pos - region_min;
			vec2 dmax = region_max - world_pos;
			sdf = min(min(dmin.x, dmax.x), min(dmin.y, dmax.y));
		}

		// 2) 三个八度噪声（拉伸对比度后）
		vec2 base = world_pos * cloud_noise_scale + vec2(edge_seed);
		float w1 = stretch(texture(mask_noise_texture, base).r);
		float w2 = stretch(texture(mask_noise_texture, base * 2.9 + vec2(0.37, 0.61) + vec2(edge_seed)).r);
		float w3 = stretch(texture(mask_noise_texture, base * 7.3 + vec2(0.11, 0.83) + vec2(edge_seed)).r);

		// 3) 用噪声扭曲包络的边界，让"区域边界"本身也是有机形状，不是直线/直角
		float warp = ((w1 - 0.5) + (w2 - 0.5) * 0.5 + (w3 - 0.5) * 0.25) * edge_noise;
		float envelope = smoother_step(-region_fade, region_fade, sdf + warp);

		// 4) 区域内部的强弱起伏：雨势在区域内也不是均匀的
		float gust = w1 * 0.6 + w2 * 0.3 + w3 * 0.1;

		mask = envelope * mix(1.0 - density_variation, 1.0, gust);
		mask = pow(clamp(mask, 0.0, 1.0), edge_gamma);
	}

	// 几何边缘渐隐：抹掉 ColorRect / Parallax 平铺接缝的硬边
	float g = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	mask *= smoother_step(0.0, edge_margin, g);

	COLOR.rgb = rain_color;
	COLOR.a *= clamp(rain, 0.0, 1.0) * density * mask;
}
