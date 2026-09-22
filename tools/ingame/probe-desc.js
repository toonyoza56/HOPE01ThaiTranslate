// Probe the item description SpriteFont: getters (non-object values), layer, visibility, text size.
(() => {
	const rt = HopeCheat.runtime;
	const by = {}; Object.values(rt.QH).forEach(c => by[c.name] = c);
	const i = by["item_stext_description"].BV()[0];
	const out = [];
	let p = Object.getPrototypeOf(i);
	while (p && p !== Object.prototype) {
		for (const [k, d] of Object.entries(Object.getOwnPropertyDescriptors(p))) if (d.get) {
			let v; try { v = i[k]; } catch (e) { v = "ERR"; }
			out.push(k + "=" + (v && typeof v === "object" ? "{" + Object.keys(v).slice(0, 6).join(",") + "}" : String(v).slice(0, 40)));
		}
		p = Object.getPrototypeOf(p);
	}
	return `runOnStartup: ${typeof self.runOnStartup}\n` + out.join("\n");
})()
