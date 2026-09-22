// Shared helpers for the Thai mod tool pages.
const HM = {
	// Save text into <project>/work/<name> through tools/serve.ps1.
	async save(name, text) {
		const res = await fetch("/work/" + encodeURIComponent(name), { method: "POST", body: text });
		if (!res.ok && res.status !== 204) throw new Error(`save ${name} failed: ${res.status}`);
	},

	// Save text or binary (Blob) into <project>/build/www/<path>.
	async saveBuild(path, body) {
		const res = await fetch("/build/" + path.split("/").map(encodeURIComponent).join("/"), { method: "POST", body });
		if (!res.ok && res.status !== 204) throw new Error(`save build/${path} failed: ${res.status}`);
	},

	// CSV with a UTF-8 BOM so Excel shows Thai correctly. Real newlines in values are
	// written as the two characters "\n" to keep one row per line.
	toCsv(rows, columns) {
		const cell = v => {
			const s = String(v ?? "").replace(/\r?\n/g, "\\n");
			return /[",]/.test(s) || /^\s|\s$/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
		};
		return "﻿" + [columns.join(","), ...rows.map(r => columns.map(c => cell(r[c])).join(","))].join("\r\n") + "\r\n";
	},

	parseCsv(text) {
		text = text.replace(/^﻿/, "");
		const rows = [];
		let row = [], cur = "", q = false;
		for (let i = 0; i < text.length; ++i) {
			const ch = text[i];
			if (q) {
				if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; ++i; } else q = false; }
				else cur += ch;
			} else if (ch === '"') q = true;
			else if (ch === ",") { row.push(cur); cur = ""; }
			else if (ch === "\n" || ch === "\r") {
				if (ch === "\r" && text[i + 1] === "\n") ++i;
				row.push(cur); rows.push(row); row = []; cur = "";
			} else cur += ch;
		}
		if (cur || row.length) { row.push(cur); rows.push(row); }
		const [head, ...body] = rows.filter(r => r.length > 1 || r[0]);
		return body.map(r => Object.fromEntries(head.map((h, i) => [h, (r[i] ?? "").replace(/\\n/g, "\n")])));
	}
};
