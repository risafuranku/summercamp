// The game's shader programs compiled ahead in the background (17. 11. 2026, Richard: "when I found a camp it is
// the biggest lag in the world"). Windows browsers (ANGLE/D3D11) compile every Godot program for 0.5-2 s on the
// page's thread: the boot to the title links ~470, founding a camp ~200 more, minutes of standing pictures the
// first time. The browser keeps compiled programs on disk, also after it closes, and Godot makes them the same every
// time. So this page compiles the same programs (the list recorded from a playthrough at deploy time,
// tools/web/record-shaders.mjs -> assets/shaders.<hash>.<n>.json, their addresses in window.__undoShaders) as soon
// as it opens, in parallel in the browser's threads (KHR_parallel_shader_compile), while the engine downloads; when
// the game asks for one, it is in the cache.
// The cache tells contexts apart: this one has exactly the attributes and the extensions of Godot's (emscripten with
// enableExtensionsByDefault, measured on Godot 4.7.1, the same in DRIVAH), else the program is compiled again. The
// result must be read (LINK_STATUS) before it is kept. A browser without parallel compiling (Safari) does nothing:
// compiling would stop the page.
// The same script as drivahgodot/web/shader-warm.js, reading the list in chunks ({texts, programs: [vs, fs,
// bindings, transform feedback]}, tools/web/qa.mjs --capture): the whole list is 80 MB of text, parsed at once it
// would stop the page and hold the memory.
(function () {
	if (window.__undoShaderWarm) return;
	const GODOT_CONTEXT = { alpha: false, depth: true, stencil: false, antialias: false, premultipliedAlpha: true, preserveDrawingBuffer: true, powerPreference: 'default', failIfMajorPerformanceCaveat: false };
	const GODOT_EXTENSIONS = ['WEBGL_multi_draw', 'EXT_polygon_offset_clamp', 'EXT_clip_control', 'WEBGL_polygon_mode', 'ANGLE_instanced_arrays',
		'OES_vertex_array_object', 'WEBGL_draw_buffers', 'WEBGL_draw_instanced_base_vertex_base_instance', 'WEBGL_multi_draw_instanced_base_vertex_base_instance',
		'EXT_disjoint_timer_query_webgl2', 'EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'EXT_conservative_depth', 'EXT_depth_clamp',
		'EXT_float_blend', 'EXT_texture_compression_bptc', 'EXT_texture_compression_rgtc', 'EXT_texture_filter_anisotropic', 'EXT_texture_norm16',
		'KHR_parallel_shader_compile', 'NV_shader_noperspective_interpolation', 'OES_texture_float_linear', 'WEBGL_blend_func_extended',
		'WEBGL_clip_cull_distance', 'WEBGL_compressed_texture_s3tc', 'WEBGL_compressed_texture_s3tc_srgb', 'OVR_multiview2'];
	// A batch is built at once and finished before the next: between batches the game's own commands get through.
	// Sent one by one the browser's GPU process was never free and the game waited 3-5 s (DRIVAH, 17. 11.).
	const BATCH = 24;
	// The browser keeps only so many compiled programs in memory and drops the oldest: compiled hundreds ahead of the
	// game, they were gone when the game asked (16. 11.: the first 40 links 0-90 ms, later ones a second each). With
	// the game running the warm stays at most AHEAD programs ahead of where the game is in the list.
	const AHEAD = 48;
	let running = null;
	const state = { done: 0, total: 0 };
	// Where the game is: its links (Godot's context, canvas #canvas) matched to the list by the shaders' text.
	let gamePos = -1;
	const index = new Map();
	const key = (vs, fs) => {
		let h = 2166136261;
		for (const t of [vs || '', fs || '']) for (let i = 0; i < t.length; i += 7) h = Math.imul(h ^ t.charCodeAt(i), 16777619);
		return `${(vs || '').length}:${(fs || '').length}:${h >>> 0}`;
	};
	(function follow() {
		const P = window.WebGL2RenderingContext && WebGL2RenderingContext.prototype;
		if (!P) return;
		const text = new WeakMap(), attached = new WeakMap();
		const shaderSource = P.shaderSource, attachShader = P.attachShader, linkProgram = P.linkProgram;
		P.shaderSource = function (shader, source) { if (this.canvas && this.canvas.id === 'canvas') text.set(shader, [source, 0]); return shaderSource.call(this, shader, source); };
		P.attachShader = function (program, shader) { if (this.canvas && this.canvas.id === 'canvas') { const l = attached.get(program) || []; l.push(shader); attached.set(program, l); } return attachShader.call(this, program, shader); };
		P.linkProgram = function (program) {
			if (this.canvas && this.canvas.id === 'canvas') {
				const sh = attached.get(program) || [];
				const src = sh.map((x) => [this.getShaderParameter(x, this.SHADER_TYPE), (text.get(x) || [''])[0]]);
				const vs = (src.find((x) => x[0] === this.VERTEX_SHADER) || [0, ''])[1], fs = (src.find((x) => x[0] === this.FRAGMENT_SHADER) || [0, ''])[1];
				const at = index.get(key(vs, fs));
				if (at !== undefined && at > gamePos) gamePos = at;
			}
			return linkProgram.call(this, program);
		};
	})();

	function build(gl, chunk, item) {
		const program = gl.createProgram();
		const shaders = [[gl.VERTEX_SHADER, chunk.texts[item[0]]], [gl.FRAGMENT_SHADER, chunk.texts[item[1]]]].map(([type, text]) => {
			const shader = gl.createShader(type);
			gl.shaderSource(shader, text || '');
			gl.compileShader(shader);
			gl.attachShader(program, shader);
			return shader;
		});
		for (const [index, name] of item[2] || []) gl.bindAttribLocation(program, index, name);
		if (item[3]) gl.transformFeedbackVaryings(program, item[3][0], item[3][1]);
		gl.linkProgram(program);
		return { program, shaders };
	}

	window.__undoShaderWarm = {
		state,
		// Compiles the list (the programs the game needs first, first); the promise settles when done or not possible.
		// `follow`: the game runs on this page, stay just ahead of it (else everything at once: a download ahead from
		// the catalogue, the programs land in the browser's disk cache for the next visit).
		run(follow = false) {
			if (running) return running;
			running = (async () => {
				const urls = window.__undoShaders;
				if (!Array.isArray(urls) || !urls.length) return;
				const gl = document.createElement('canvas').getContext('webgl2', GODOT_CONTEXT);
				const parallel = gl && gl.getExtension('KHR_parallel_shader_compile');
				if (!parallel) return;
				for (const name of GODOT_EXTENSIONS) gl.getExtension(name);
				const load = (url) => fetch(url).then((r) => r.json());
				const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
				state.total = Number(window.__undoShadersTotal) || 0;
				// where the game is in the whole list, from the start (else it links programs of a chunk not read yet and
				// the warm, waiting for it, never moves on)
				if (follow && window.__undoShaderKeys) {
					const keys = await load(window.__undoShaderKeys);
					keys.forEach((k, i) => index.set(k, i));
				}
				let next = load(urls[0]);
				let base = 0;
				for (let c = 0; c < urls.length; c++) {
					const chunk = await next;
					next = c + 1 < urls.length ? load(urls[c + 1]) : null;
					if (!window.__undoShaderKeys) chunk.programs.forEach((item, i) => index.set(key(chunk.texts[item[0]], chunk.texts[item[1]]), base + i));
					for (let at = 0; at < chunk.programs.length; at += BATCH) {
						// what the game has linked already is skipped; far ahead of it, wait
						while (follow && base + at > gamePos + AHEAD) await wait(100);
						const items = chunk.programs.slice(at, at + BATCH).filter((item, i) => !follow || base + at + i > gamePos);
						state.done += Math.min(BATCH, chunk.programs.length - at) - items.length;
						const batch = items.map((item) => build(gl, chunk, item));
						while (batch.length) {
							for (let i = batch.length - 1; i >= 0; i--) {
								const { program, shaders } = batch[i];
								if (!gl.getProgramParameter(program, parallel.COMPLETION_STATUS_KHR)) continue;
								gl.getProgramParameter(program, gl.LINK_STATUS);
								shaders.forEach((shader) => gl.deleteShader(shader));
								gl.deleteProgram(program);
								batch.splice(i, 1);
								state.done += 1;
							}
							if (batch.length) await wait(40);
						}
					}
					base += chunk.programs.length;
				}
				const lose = gl.getExtension('WEBGL_lose_context');
				if (lose) lose.loseContext();
			})().catch((error) => console.warn('shader warm:', error));
			return running;
		},
	};
})();
