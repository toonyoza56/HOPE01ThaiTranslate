// Experiment: show a 2-line dialogue, then shrink the SpriteFont line height so glyph cells overlap
// the line above. self.OVL = extra line height (negative), self.OVL_FX = false to disable effects.
(async () => {
	const by = {}; Object.values(HopeCheat.runtime.QH).forEach(c => by[c.name] = c);
	const i = by["ui_dialogue_textframe_text"].BV()[0];
	if (self.OVL_BASE === undefined) self.OVL_BASE = i.lineHeight;
	i.lineHeight = self.OVL_BASE + (self.OVL || 0);
	const fx = i.effects || [];
	for (const e of fx) if ("isActive" in e) e.isActive = self.OVL_FX !== false;
	const find = (o, k) => { let p = o; while (p) { const d = Object.getOwnPropertyDescriptor(p, k); if (d) return true; p = Object.getPrototypeOf(p); } return false; };
	return JSON.stringify({ lh: i.lineHeight, effects: fx.length, hasEffects: find(i, "effects"), layer: String(i.layer && i.layer.name), blend: i.blendMode });
})()
