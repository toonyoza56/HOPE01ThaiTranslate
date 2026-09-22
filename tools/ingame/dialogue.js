(async () => {
	if (!self.THS3) {
		const d = await fetch("data.json").then(r => r.json());
		const arr = [];
		const scan = x => { if (!Array.isArray(x)) return; for (let k = 0; k + 2 < x.length; k++) if (x[k + 1] === "dialogue" && typeof x[k + 2] === "string" && /[฀-๿-]/.test(x[k + 2])) arr.push(x[k + 2]); x.forEach(scan); };
		scan(d.project[49]);
		self.THS3 = arr;
	}
	const pick = self.PICK || "CYCLER";
	const t = pick === "longest" ? [...THS3].sort((a, b) => b.length - a.length)[0] : THS3.find(s => s.includes(pick));
	HopeCheat.runtime.AU("DialogueShow", t, "hermes");
	await new Promise(r => setTimeout(r, 2500));
	return t.length;
})()
