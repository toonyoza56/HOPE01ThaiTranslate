(async () => {
	// Map Thai graphemes -> encoded glyph chars by aligning a known translation with its encoded text.
	const src = "ก็ไม่ค่อยดีเท่าไหร่...\nFABRICKS ของฉันใกล้หมดแล้ว...";
	const enc = THS3.find(s => s.startsWith(src.slice(0, 0)) && s.includes("FABRICKS ") && s.includes("..."+"\n"));
	const encChars = [...enc].filter(c => c !== "​");
	const map = new Map(); let k = 0;
	for (const { segment } of new Intl.Segmenter("th", { granularity: "grapheme" }).segment(src)) { map.set(segment, encChars[k++]); }
	self.GMAP = map;
	const e = s => [...new Intl.Segmenter("th", { granularity: "grapheme" }).segment(s)].map(x => map.get(x.segment) || x.segment).join("");
	const text = self.TEST || "ไม่ ไม่ ไม่ ค่อย\nไม่ ไม่ ค่อย";
	HopeCheat.runtime.AU("DialogueShow", e(text), "hermes");
	await new Promise(r => setTimeout(r, 2000));
	return JSON.stringify({ enc: enc.slice(0, 40), mapped: [...map].slice(0, 8).map(([a, b]) => a + "=" + b.codePointAt(0).toString(16)) });
})()
