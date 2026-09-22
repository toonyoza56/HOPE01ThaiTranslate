(async () => {
	const d = await fetch("data.json").then(r => r.json());
	const opts = [];
	const scan = x => { if (!Array.isArray(x)) return; for (let k = 0; k + 2 < x.length; k++) if (/^option[1-4]$/.test(x[k + 1]) && typeof x[k + 2] === "string" && /[฀-๿-]/.test(x[k + 2])) opts.push(x[k + 2]); x.forEach(scan); };
	scan(d.project[49]);
	const longest = [...new Set(opts)].sort((a, b) => b.length - a.length);
	const pick = [longest[0], longest[1], opts.find(s => s.includes("SHASTA")) || longest[2], opts.find(s => s.length < 12) || longest[3]];
	HopeCheat.runtime.AU("DialogueBoxChoices", ...pick);
	await new Promise(r => setTimeout(r, 800));
	const by = {}; Object.values(HopeCheat.runtime.QH).forEach(c => by[c.name] = c);
	return [1, 2, 3, 4].map(k => { const i = by["ui_dialogue_textframe_choice" + k].BV()[0]; return `c${k} y=${i.y} h=${i.height} scale=${i.w6t}`; }).join("\n");
})()
