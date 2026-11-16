// Zbytečné překlady shaderů (Godot 4.7 Compatibility, drivers/gles3/shader_gles3.cpp):
// při prvním použití materiálu ShaderGLES3::_initialize_version přeloží výchozí specializaci
// všech variant (scene.glsl #[specializations]: true jen BASE_PASS, USE_RADIANCE_MAP,
// DISABLE_REFLECTION_PROBE, APPLY_TONEMAPPING), tedy barevnou verzi se všemi bodovými,
// reflektorovými a plošnými světly, lightmapou a mlhou zároveň. Kreslí se specializace podle
// scény (rasterizer_scene_gles3.cpp _render_list_template): objekt bez lightmapy má vždycky
// DISABLE_LIGHTMAP, bez bodového světla DISABLE_LIGHT_OMNI atd., takže přesně výchozí
// specializace se nekreslí nikdy (hra nemá lightmapy Godotu). Na Windows (ANGLE/D3D11) se
// taková barevná verze překládá 1,5–3 s a blokuje celou stránku; tady dostane prázdný shader.
// Hloubkové varianty (MODE_RENDER_DEPTH) jsou levné a zůstávají. S ?trace=1 hlásí konzole,
// kdyby se prázdným programem přece jen kreslilo.
(function () {
	const proto = window.WebGL2RenderingContext && WebGL2RenderingContext.prototype;
	if (!proto) return;
	const VERTEX = '#version 300 es\nvoid main() { gl_Position = vec4(0.0); }\n';
	const FRAGMENT = '#version 300 es\nprecision mediump float;\nout vec4 frag_color;\nvoid main() { frag_color = vec4(0.0); }\n';
	const SPECIALIZATIONS = ['DISABLE_LIGHTMAP', 'DISABLE_LIGHT_DIRECTIONAL', 'DISABLE_LIGHT_OMNI', 'DISABLE_LIGHT_SPOT', 'DISABLE_LIGHT_AREA',
		'DISABLE_REFLECTION_PROBE', 'DISABLE_FOG', 'USE_DEPTH_FOG', 'USE_SUN_SCATTER', 'USE_RADIANCE_MAP', 'USE_LIGHTMAP', 'USE_SH_LIGHTMAP',
		'USE_LIGHTMAP_CAPTURE', 'USE_MULTIVIEW', 'RENDER_SHADOWS', 'RENDER_SHADOWS_LINEAR', 'SHADOW_MODE_PCF_5', 'SHADOW_MODE_PCF_13',
		'LIGHT_USE_PSSM2', 'LIGHT_USE_PSSM4', 'LIGHT_USE_PSSM_BLEND', 'BASE_PASS', 'USE_ADDITIVE_LIGHTING', 'APPLY_TONEMAPPING',
		'ADDITIVE_OMNI', 'ADDITIVE_SPOT', 'RENDER_MATERIAL', 'SECOND_REFLECTION_PROBE', 'LIGHTMAP_BICUBIC_FILTER', 'RENDER_MOTION_VECTORS'];
	const DEFAULTS = 'APPLY_TONEMAPPING BASE_PASS DISABLE_REFLECTION_PROBE USE_RADIANCE_MAP';
	// Barevná varianta scénového shaderu (globální define MAX_FORWARD_LIGHTS) v přesně výchozí specializaci.
	// Specializace a globální define jsou v hlavičce zdroje (do ~1,5 kB z ~90 kB), hledá se jen v ní: regulární
	// výraz přes celý zdroj stál při prvním hraní DRIVAHu 0,85 s hlavního vlákna (17. 11., profil Chromu).
	const unused = (full) => {
		const source = full.slice(0, 8192);
		if (!source.includes('\n#define MAX_FORWARD_LIGHTS ') || /^#define MODE_RENDER_DEPTH\b/m.test(source)) return false;
		const defines = new Set(source.match(/^#define [A-Z0-9_]+$/gm) || []);
		return SPECIALIZATIONS.filter((name) => defines.has('#define ' + name)).join(' ').split(' ').sort().join(' ') === DEFAULTS;
	};
	const types = new WeakMap();
	const empty = new WeakSet();
	const createShader = proto.createShader;
	proto.createShader = function (type) {
		const shader = createShader.call(this, type);
		if (shader) types.set(shader, type);
		return shader;
	};
	const shaderSource = proto.shaderSource;
	proto.shaderSource = function (shader, source) {
		if (unused(source)) {
			empty.add(shader);
			return shaderSource.call(this, shader, types.get(shader) === this.VERTEX_SHADER ? VERTEX : FRAGMENT);
		}
		return shaderSource.call(this, shader, source);
	};
	window.__swGlSkip = { skipped: 0, drawn: 0 };
	const skipped = new WeakSet();
	const attachShader = proto.attachShader;
	proto.attachShader = function (program, shader) {
		if (empty.has(shader) && !skipped.has(program)) {
			skipped.add(program);
			window.__swGlSkip.skipped++;
		}
		return attachShader.call(this, program, shader);
	};
	// Pojistka pro testy (?trace=1): kreslení prázdným programem by znamenalo chybějící objekt.
	if (!/[?&]trace=/.test(location.search)) return;
	let current = null;
	const useProgram = proto.useProgram;
	proto.useProgram = function (program) {
		current = program;
		return useProgram.call(this, program);
	};
	for (const name of ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced', 'drawRangeElements']) {
		const draw = proto[name];
		proto[name] = function (...args) {
			if (current && skipped.has(current) && window.__swGlSkip.drawn++ === 0) console.warn('[gl-skip] kreslí se prázdným shaderem');
			return draw.apply(this, args);
		};
	}
}());
