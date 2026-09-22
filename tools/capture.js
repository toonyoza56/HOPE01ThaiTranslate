// Full-resolution screenshot of the running game (used while testing in /play/).
// Reads the WebGL back buffer right after the top layer has drawn, so the image is the real
// rendered frame at canvas resolution (not the scaled-down preview pane).
//   const { capture } = await import('/tools/capture.js');
//   await capture('shot-menu.png', { x: 0, y: 0.45, w: 0.45, h: 0.5 });   // crop in 0..1 units
export async function capture(name, crop = { x: 0, y: 0, w: 1, h: 1 }) {
	const rt = self.HopeCheat && self.HopeCheat.runtime;
	if (!rt) throw new Error("HopeCheat runtime handle not available (is hope_cheat.js loaded?)");
	const layers = rt.layout.jq();
	const top = layers[layers.length - 1];
	const canvas = [...document.querySelectorAll("canvas")]
		.filter(c => c.id !== "hopecheat-overlay")
		.sort((a, b) => b.width * b.height - a.width * a.height)[0];
	const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
	const shot = await new Promise(res => {
		const f = () => {
			top.removeEventListener("afterdraw", f);
			queueMicrotask(() => {
				gl.bindFramebuffer(gl.FRAMEBUFFER, null);
				const w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
				const px = new Uint8Array(w * h * 4);
				gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, px);
				res({ w, h, px });
			});
		};
		top.addEventListener("afterdraw", f);
	});
	const full = document.createElement("canvas");
	full.width = shot.w; full.height = shot.h;
	const g = full.getContext("2d");
	const img = g.createImageData(shot.w, shot.h);
	for (let y = 0; y < shot.h; y++) img.data.set(shot.px.subarray((shot.h - 1 - y) * shot.w * 4, (shot.h - y) * shot.w * 4), y * shot.w * 4);
	for (let i = 3; i < img.data.length; i += 4) img.data[i] = 255;
	g.putImageData(img, 0, 0);
	const cx = Math.round(crop.x * shot.w), cy = Math.round(crop.y * shot.h);
	const cw = Math.round(crop.w * shot.w), ch = Math.round(crop.h * shot.h);
	const out = document.createElement("canvas");
	out.width = cw; out.height = ch;
	out.getContext("2d").drawImage(full, cx, cy, cw, ch, 0, 0, cw, ch);
	const blob = await new Promise(r => out.toBlob(r, "image/png"));
	await fetch("/work/" + encodeURIComponent(name), { method: "POST", body: blob });
	return `${shot.w}x${shot.h} -> work/${name} (${cw}x${ch})`;
}
