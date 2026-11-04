// VFX cutscene: tebasan bulan sabit, gelombang tebasan raksasa, ledakan cahaya, gelombang kejut, petir,
// retakan ruang (udara pecah kayak kaca, sobekan ruang bekas tebasan), retakan tanah bercahaya, serpihan jatuh,
// pedang pecah, kilau pedang, debu, pasukan terhempas, afterimage. Pakai tekstur sendiri yang udah di-upload
// + partikel (murah, bisa di-batch GPU). Jumlah partikel dikali q.particles, lapisan ekstra cuma di tier tinggi.

import { Workspace } from "@rbxts/services";
import { ease } from "shared/cutscene/ease";
import { TEX } from "shared/cutscene/audio";
import { Actor } from "./actors";
import { Quality } from "./quality";
import { Tweens } from "./tweens";

const WHITE = new Color3(1, 1, 1);
const UP = new Vector3(0, 1, 0);
/** Warna tinta (gaya pedang Bai Wuji): hitam kebiruan, gak menyala. */
const INK = Color3.fromRGB(12, 12, 16);

export interface VfxCtx {
	root: Folder;
	tw: Tweens;
	origin: CFrame;
	q: Quality;
	/** Kecepatan timeline sekarang, buat TimeScale partikel. */
	rate: number;
	emitters: ParticleEmitter[];
}

const kp = (t: number, v: number) => new NumberSequenceKeypoint(t, v);
const seq = (...points: [number, number][]) => new NumberSequence(points.map(([t, v]) => kp(t, v)));

function host(ctx: VfxCtx, cf: CFrame, life?: number): Part {
	const p = new Instance("Part");
	p.Name = "Fx";
	p.Size = new Vector3(0.2, 0.2, 0.2);
	p.Transparency = 1;
	p.Anchored = true;
	p.CanCollide = false;
	p.CanQuery = false;
	p.CanTouch = false;
	p.CastShadow = false;
	p.CFrame = cf;
	p.Parent = ctx.root;
	if (life !== undefined) ctx.tw.after(life, () => p.Destroy());
	return p;
}

function emitter(ctx: VfxCtx, parent: Instance, props: Partial<WritableInstanceProperties<ParticleEmitter>>) {
	const e = new Instance("ParticleEmitter");
	e.Enabled = false;
	e.Rate = 0;
	e.LightEmission = 1;
	e.LightInfluence = 0;
	e.Speed = new NumberRange(0);
	e.TimeScale = ctx.rate;
	for (const [k, v] of pairs(props as Record<string, unknown>)) (e as unknown as Record<string, unknown>)[k] = v;
	e.Parent = parent;
	ctx.emitters.push(e);
	return e;
}

const count = (ctx: VfxCtx, n: number) => math.max(1, math.floor(n * ctx.q.particles + 0.5));

/** Cipratan tinta: gumpalan asap hitam + tetesan yang jatuh. */
function inkSplash(ctx: VfxCtx, parent: Instance, scale: number, n: number) {
	emitter(ctx, parent, {
		Texture: TEX.smokeFlip,
		FlipbookLayout: Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode: Enum.ParticleFlipbookMode.OneShot,
		Color: new ColorSequence(INK),
		LightEmission: 0,
		Size: seq([0, 0.8 * scale], [1, 2.8 * scale]),
		Transparency: seq([0, 0.1], [0.7, 0.35], [1, 1]),
		Lifetime: new NumberRange(0.5, 0.9),
		Speed: new NumberRange(6, 16),
		SpreadAngle: new Vector2(180, 180),
		Drag: 4,
		Rotation: new NumberRange(0, 360),
	}).Emit(count(ctx, n));
	emitter(ctx, parent, {
		Texture: TEX.glow,
		Color: new ColorSequence(INK),
		LightEmission: 0,
		Size: seq([0, 0.35 * scale], [1, 0.1 * scale]),
		Transparency: seq([0, 0], [1, 0.3]),
		Lifetime: new NumberRange(0.4, 0.8),
		Speed: new NumberRange(14, 30),
		SpreadAngle: new Vector2(180, 180),
		Acceleration: new Vector3(0, -40, 0),
		Drag: 2,
	}).Emit(count(ctx, n * 1.5));
}

export function slash(ctx: VfxCtx, from: Vector3, to: Vector3, color: Color3, scale = 1, dur = 0.45, ink = false) {
	const A = ctx.origin.PointToWorldSpace(from);
	const B = ctx.origin.PointToWorldSpace(to);
	const len = B.sub(A).Magnitude;
	const h = host(ctx, new CFrame(A), dur + 0.1);
	const a0 = new Instance("Attachment");
	a0.Parent = h;
	const a1 = new Instance("Attachment");
	a1.Parent = h;
	const beam = (width: number, c: Color3) => {
		const b = new Instance("Beam");
		b.Attachment0 = a0;
		b.Attachment1 = a1;
		b.Texture = TEX.crescent;
		b.TextureMode = Enum.TextureMode.Stretch;
		b.TextureLength = 1;
		b.FaceCamera = true;
		b.LightEmission = 1;
		b.LightInfluence = 0;
		b.Segments = 6;
		b.Width0 = width;
		b.Width1 = width;
		b.Color = new ColorSequence(c);
		b.Parent = h;
		return b;
	};
	const w = len * 0.5 * scale;
	// Tinta digambar duluan (di bawah), cahaya di atasnya: sapuan kuas hitam dengan inti qi bercahaya
	if (ink) {
		const stroke = beam(w * 1.3, INK);
		stroke.LightEmission = 0;
		ctx.tw.add(dur * 1.8, (k) => {
			stroke.Transparency = new NumberSequence(k < 0.35 ? 0.05 : 0.05 + 0.95 * ((k - 0.35) / 0.65));
			stroke.Width0 = w * (1.3 + 0.25 * k);
			stroke.Width1 = w * (1.3 + 0.25 * k);
		});
	}
	const outer = beam(w, color);
	const core = beam(w * 0.45, WHITE);
	// Muncul cepat dari A ke B, terus memudar dan menipis
	ctx.tw.add(0.07, (k) => (a1.WorldPosition = A.Lerp(B, ease("out", k))));
	ctx.tw.add(dur, (k) => {
		const tr = new NumberSequence(math.clamp((k - 0.25) / 0.75, 0, 1));
		const shrink = 1 - 0.4 * k;
		outer.Transparency = tr;
		core.Transparency = tr;
		outer.Width0 = w * shrink;
		outer.Width1 = w * shrink;
		core.Width0 = w * 0.45 * shrink;
		core.Width1 = w * 0.45 * shrink;
	});
	const mid = host(ctx, new CFrame(A.Lerp(B, 0.5)), 1);
	emitter(ctx, mid, {
		Texture: TEX.spark,
		Color: new ColorSequence(color),
		Size: seq([0, 0.5 * scale], [1, 0]),
		Lifetime: new NumberRange(0.2, 0.45),
		Speed: new NumberRange(12, 30),
		SpreadAngle: new Vector2(180, 180),
		Drag: 5,
	}).Emit(count(ctx, 14));
	if (ink && ctx.q.tier >= 1) inkSplash(ctx, mid, scale, 8);
	// Garis potong putih tipis ala anime, sekejap
	if (ctx.q.tier >= 1) {
		const line = host(ctx, CFrame.lookAt(A.Lerp(B, 0.5), B), 0.35);
		line.Size = new Vector3(0.12 * scale, 0.12 * scale, len * 1.1);
		line.Transparency = 0;
		line.Material = Enum.Material.Neon;
		line.Color = WHITE;
		ctx.tw.add(0.3, (k) => {
			line.Transparency = k;
			line.Size = new Vector3(0.12 * scale * (1 - k), 0.12 * scale * (1 - k), len * 1.1);
		});
	}
}

/** Bulan sabit raksasa yang terbang dari `from` ke `to` sambil membesar (tebasan jarak jauh). */
export function wave(ctx: VfxCtx, from: Vector3, to: Vector3, color: Color3, scale = 1, dur = 0.5, ink = false) {
	const A = ctx.origin.PointToWorldSpace(from);
	const B = ctx.origin.PointToWorldSpace(to);
	const dir = B.sub(A).Unit;
	const flat = dir.Cross(UP);
	const side = flat.Magnitude > 0.1 ? flat.Unit : new Vector3(1, 0, 0);
	const tilt = UP.mul(0.3);
	const h = host(ctx, new CFrame(A), dur + 0.4);
	const a0 = new Instance("Attachment");
	a0.Parent = h;
	const a1 = new Instance("Attachment");
	a1.Parent = h;
	const beam = (c: Color3) => {
		const b = new Instance("Beam");
		b.Attachment0 = a0;
		b.Attachment1 = a1;
		b.Texture = TEX.crescent;
		b.TextureMode = Enum.TextureMode.Stretch;
		b.FaceCamera = true;
		b.LightEmission = 1;
		b.LightInfluence = 0;
		b.Segments = 8;
		b.Color = new ColorSequence(c);
		b.Parent = h;
		return b;
	};
	const stroke = ink ? beam(INK) : undefined;
	if (stroke) stroke.LightEmission = 0;
	const outer = beam(color);
	const core = beam(WHITE);
	const head = host(ctx, new CFrame(A), dur + 0.8);
	const inkTrail =
		ink && ctx.q.tier >= 1
			? emitter(ctx, head, {
					Texture: TEX.smokeFlip,
					FlipbookLayout: Enum.ParticleFlipbookLayout.Grid4x4,
					FlipbookMode: Enum.ParticleFlipbookMode.OneShot,
					Color: new ColorSequence(INK),
					LightEmission: 0,
					Size: seq([0, 3 * scale], [1, 9 * scale]),
					Transparency: seq([0, 0.2], [1, 1]),
					Lifetime: new NumberRange(0.6, 1),
					Speed: new NumberRange(2, 6),
					SpreadAngle: new Vector2(180, 180),
					Rotation: new NumberRange(0, 360),
					Rate: 60 * ctx.q.particles,
				})
			: undefined;
	if (inkTrail) inkTrail.Enabled = true;
	const trail = emitter(ctx, head, {
		Texture: TEX.spark,
		Color: new ColorSequence(WHITE, color),
		Size: seq([0, 0.8 * scale], [1, 0]),
		Lifetime: new NumberRange(0.3, 0.6),
		Speed: new NumberRange(4, 14),
		SpreadAngle: new Vector2(180, 180),
		Drag: 3,
		Rate: 160 * ctx.q.particles,
	});
	trail.Enabled = true;
	const h0 = 5 * scale;
	const h1 = 45 * scale;
	ctx.tw.add(
		dur,
		(k) => {
			const e = ease("out", k);
			const c = A.Lerp(B, e);
			const half = h0 + (h1 - h0) * e;
			a0.WorldPosition = c.add(side.add(tilt).mul(half));
			a1.WorldPosition = c.sub(side.add(tilt).mul(half));
			head.CFrame = new CFrame(c);
			const w = half * 0.8;
			outer.Width0 = w;
			outer.Width1 = w;
			core.Width0 = w * 0.4;
			core.Width1 = w * 0.4;
			const tr = new NumberSequence(k < 0.7 ? 0 : (k - 0.7) / 0.3);
			outer.Transparency = tr;
			core.Transparency = tr;
			if (stroke) {
				stroke.Width0 = w * 1.25;
				stroke.Width1 = w * 1.25;
				stroke.Transparency = new NumberSequence(k < 0.8 ? 0.05 : 0.05 + 0.95 * ((k - 0.8) / 0.2));
			}
		},
		() => {
			trail.Enabled = false;
			if (inkTrail) inkTrail.Enabled = false;
		},
	);
}

/** Petir dari langit (from) ke titik (to): patah-patah, kedip, cabang di grafik sedang ke atas. */
export function lightning(ctx: VfxCtx, from: Vector3, to: Vector3, color: Color3, scale = 1) {
	const A = ctx.origin.PointToWorldSpace(from);
	const B = ctx.origin.PointToWorldSpace(to);
	const rng = new Random();
	const segs = ctx.q.tier === 0 ? 6 : 10;
	const step = B.sub(A).Magnitude / segs;
	const parts: Part[] = [];
	const bolt = (pts: Vector3[], width: number) => {
		for (let i = 0; i < pts.size() - 1; i++) {
			const a = pts[i];
			const b = pts[i + 1];
			const p = host(ctx, CFrame.lookAt(a.Lerp(b, 0.5), b), 0.6);
			p.Size = new Vector3(width, width, b.sub(a).Magnitude + width);
			p.Transparency = 0;
			p.Material = Enum.Material.Neon;
			p.Color = color;
			parts.push(p);
		}
	};
	const main = [A];
	for (let i = 1; i < segs; i++) main.push(A.Lerp(B, i / segs).add(rng.NextUnitVector().mul(step * 0.45)));
	main.push(B);
	bolt(main, 0.7 * scale);
	if (ctx.q.tier >= 1) {
		for (let b = 0; b < 2; b++) {
			const start = main[rng.NextInteger(2, segs - 2)];
			const branch = [start];
			let p = start;
			for (let i = 0; i < 3; i++) {
				p = p.add(B.sub(A).Unit.mul(step * 0.6)).add(rng.NextUnitVector().mul(step * 0.6));
				branch.push(p);
			}
			bolt(branch, 0.35 * scale);
		}
	}
	// Kedip: nyala, redup, nyala lagi, hilang
	ctx.tw.add(0.5, (k) => {
		const tr = k < 0.12 ? 0 : k < 0.22 ? 0.75 : k < 0.32 ? 0.05 : (k - 0.32) / 0.68;
		for (const p of parts) p.Transparency = tr;
	});
	burst(ctx, to, color, 0.6 * scale);
	if (ctx.q.lights) {
		const glow = host(ctx, new CFrame(A.Lerp(B, 0.7)), 0.6);
		const light = new Instance("PointLight");
		light.Color = color;
		light.Range = 60;
		light.Parent = glow;
		ctx.tw.add(0.5, (k) => (light.Brightness = 8 * (1 - k)));
	}
}

/** Satu garis retak di bidang 2D: dari a ke b, muncul pas "jari-jari" retakan lewat d0..d1. */
interface Seg {
	a: Vector2;
	b: Vector2;
	d0: number;
	d1: number;
	w: number;
}

/** Titik di polyline sinar pada jarak tempuh d (buat jaring kaca). */
function pointAt(pts: Array<[Vector2, number]>, d: number): Vector2 | undefined {
	for (let i = 1; i < pts.size(); i++) {
		const [p0, d0] = pts[i - 1];
		const [p1, d1] = pts[i];
		if (d <= d1) return p0.Lerp(p1, (d - d0) / math.max(d1 - d0, 1e-3));
	}
	return undefined;
}

/**
 * Pola retakan: sinar patah-patah dari pusat (makin ke ujung makin tipis), cabang, dan jaring melingkar
 * kayak kaca dihantam. Semua di bidang 2D, nanti dipetakan ke 3D.
 */
function crackPattern(rng: Random, radius: number, rays: number, branchChance: number, web: boolean, width: number): Seg[] {
	const segs: Seg[] = [];
	const rayPts: Array<Array<[Vector2, number]>> = [];
	for (let r = 0; r < rays; r++) {
		let heading = (r / rays) * math.pi * 2 + rng.NextNumber(-0.3, 0.3);
		let p = Vector2.zero;
		let dist = 0;
		const reach = radius * rng.NextNumber(0.62, 1);
		const pts: Array<[Vector2, number]> = [[p, 0]];
		while (dist < reach) {
			const len = radius * rng.NextNumber(0.09, 0.19);
			heading += rng.NextNumber(-0.5, 0.5);
			const q = p.add(new Vector2(math.cos(heading), math.sin(heading)).mul(len));
			const w = width * (1 - 0.7 * (dist / radius));
			segs.push({ a: p, b: q, d0: dist, d1: dist + len, w });
			if (dist > radius * 0.12 && rng.NextNumber() < branchChance) {
				let bh = heading + (rng.NextNumber() < 0.5 ? -1 : 1) * rng.NextNumber(0.5, 1.1);
				let bp = q;
				let bd = dist + len;
				const n = rng.NextInteger(1, 3);
				for (let k = 0; k < n; k++) {
					const bl = radius * rng.NextNumber(0.05, 0.12);
					bh += rng.NextNumber(-0.4, 0.4);
					const bq = bp.add(new Vector2(math.cos(bh), math.sin(bh)).mul(bl));
					segs.push({ a: bp, b: bq, d0: bd, d1: bd + bl, w: w * 0.55 });
					bp = bq;
					bd += bl;
				}
			}
			p = q;
			dist += len;
			pts.push([p, dist]);
		}
		rayPts.push(pts);
	}
	if (web) {
		for (const frac of [0.28, 0.52, 0.78]) {
			const rr = radius * frac;
			for (let r = 0; r < rays; r++) {
				if (rng.NextNumber() < 0.3) continue;
				const A = pointAt(rayPts[r], rr * rng.NextNumber(0.92, 1.08));
				const B = pointAt(rayPts[(r + 1) % rays], rr * rng.NextNumber(0.92, 1.08));
				if (!A || !B) continue;
				const mid = A.Lerp(B, 0.5).mul(rng.NextNumber(0.9, 1.05));
				const span = A.sub(B).Magnitude;
				segs.push({ a: A, b: mid, d0: rr, d1: rr + span * 0.5, w: width * 0.32 });
				segs.push({ a: mid, b: B, d0: rr + span * 0.5, d1: rr + span, w: width * 0.32 });
			}
		}
	}
	return segs;
}

interface CrackNet {
	parts: BasePart[];
	reveal: (r: number) => void;
	/** Jari-jari sekarang (buat animasi melebar). */
	r: number;
}

/**
 * Gambar pola retakan di bidang (pusat P, sumbu kanan/atas, normal N menghadap penonton):
 * inti hitam (celah ke ruang hampa) di depan, pinggiran neon lebih lebar di belakangnya, jadi kelihatan
 * celah gelap dengan tepi menyala. Awalnya kosong, `reveal(r)` munculin semua garis sampai jari-jari r.
 */
function crackNet(ctx: VfxCtx, segs: Seg[], P: Vector3, right: Vector3, up: Vector3, N: Vector3, rim: Color3, thick: number): CrackNet {
	const parts: BasePart[] = [];
	const to3 = (v: Vector2) => P.add(right.mul(v.X)).add(up.mul(v.Y));
	const items = segs.map((sg) => {
		const a = to3(sg.a);
		const b = to3(sg.b);
		const dir = b.sub(a).Unit;
		const len = b.sub(a).Magnitude;
		const core = host(ctx, new CFrame(a));
		core.Material = Enum.Material.SmoothPlastic;
		core.Color = Color3.fromRGB(4, 3, 9);
		const glow = host(ctx, new CFrame(a));
		glow.Material = Enum.Material.Neon;
		glow.Color = rim;
		parts.push(core, glow);
		return { sg, a, dir, len, core, glow, vis: -1 };
	});
	const net: CrackNet = {
		parts,
		r: 0,
		reveal: (r) => {
			net.r = r;
			for (const it of items) {
				const { sg } = it;
				const vis = sg.d1 > sg.d0 ? math.clamp((r - sg.d0) / (sg.d1 - sg.d0), 0, 1) : r >= sg.d0 ? 1 : 0;
				if (math.abs(vis - it.vis) < 0.01) continue;
				it.vis = vis;
				if (vis <= 0) {
					it.core.Transparency = 1;
					it.glow.Transparency = 1;
					continue;
				}
				const l = it.len * vis;
				const mid = it.a.add(it.dir.mul(l / 2));
				const cf = CFrame.lookAt(mid, mid.add(it.dir), N);
				it.core.CFrame = cf.add(N.mul(thick * 0.6));
				it.core.Size = new Vector3(sg.w, thick, l + sg.w * 0.5);
				it.core.Transparency = 0;
				it.glow.CFrame = cf;
				it.glow.Size = new Vector3(sg.w * 2.6 + 0.06, thick, l + sg.w * 1.6);
				it.glow.Transparency = 0.12;
			}
		},
	};
	return net;
}

/** Tween jari-jari retakan ke `to`. */
function growNet(ctx: VfxCtx, net: CrackNet, to: number, dur: number) {
	const from = net.r;
	ctx.tw.add(dur, (k) => net.reveal(from + (to - from) * ease("out", k)));
}

/** Retakan memudar terus dihapus. `keepCore` = celah hitam tetap ada (retakan tanah). */
function fadeNet(ctx: VfxCtx, net: CrackNet, dur: number, keepCore: boolean) {
	const glows = net.parts.filter((p) => p.Material === Enum.Material.Neon && p.Transparency < 1);
	const cores = net.parts.filter((p) => p.Material !== Enum.Material.Neon && p.Transparency < 1);
	ctx.tw.add(
		dur,
		(k) => {
			for (const g of glows) g.Transparency = 0.12 + 0.88 * k;
			if (!keepCore) for (const c of cores) c.Transparency = k;
		},
		() => {
			for (const g of glows) g.Destroy();
			if (!keepCore) for (const c of cores) c.Destroy();
		},
	);
}

/** Basis bidang yang menghadap kamera di titik P: [kanan, atas, normal]. */
function facing(P: Vector3): [Vector3, Vector3, Vector3] {
	const cam = Workspace.CurrentCamera;
	const toCam = cam ? cam.CFrame.Position.sub(P) : new Vector3(0, 0, 1);
	const N = toCam.Magnitude > 0.01 ? toCam.Unit : new Vector3(0, 0, 1);
	const basis = CFrame.lookAt(P, P.add(N));
	return [basis.RightVector, basis.UpVector, N];
}

/** Retakan tanah: celah gelap bercabang dengan tepi bercahaya yang meredup (celahnya tetap ada). */
export function cracks(ctx: VfxCtx, at: Vector3, scale = 1, glow?: Color3) {
	const P = ctx.origin.PointToWorldSpace(at).add(new Vector3(0, 0.04, 0));
	const rng = new Random();
	const rays = ctx.q.tier === 0 ? 7 : ctx.q.tier === 1 ? 10 : 13;
	const segs = crackPattern(rng, 9 * scale, rays, ctx.q.tier >= 1 ? 0.45 : 0.2, false, 0.32 * scale);
	const net = crackNet(ctx, segs, P, new Vector3(1, 0, 0), new Vector3(0, 0, 1), new Vector3(0, 1, 0), glow ?? Color3.fromRGB(255, 170, 90), 0.05);
	growNet(ctx, net, 9 * scale, 0.28);
	ctx.tw.after(0.6, () => fadeNet(ctx, net, 2.8, true));
	if (ctx.q.lights && glow) {
		const h = host(ctx, new CFrame(P.add(new Vector3(0, 1, 0))), 2.5);
		const l = new Instance("PointLight");
		l.Color = glow;
		l.Range = 14 * scale;
		l.Parent = h;
		ctx.tw.add(2.4, (k) => (l.Brightness = 3 * (1 - k)));
	}
}

/** Pecahan kaca ruang: segitiga bening yang terlempar dari bidang retakan ke arah kamera lalu jatuh pelan. */
function glassShards(ctx: VfxCtx, P: Vector3, right: Vector3, up: Vector3, N: Vector3, radius: number, scale: number, tint: Color3) {
	const rng = new Random();
	const n = ctx.q.tier === 0 ? 10 : ctx.q.tier === 1 ? 22 : 36;
	for (let i = 0; i < n; i++) {
		const ang = rng.NextNumber(0, math.pi * 2);
		const rr = radius * math.sqrt(rng.NextNumber(0.02, 1));
		const offset = right.mul(math.cos(ang) * rr).add(up.mul(math.sin(ang) * rr));
		const start = P.add(offset);
		const wedge = new Instance("WedgePart");
		wedge.Name = "Fx";
		wedge.Anchored = true;
		wedge.CanCollide = false;
		wedge.CanQuery = false;
		wedge.CanTouch = false;
		wedge.CastShadow = false;
		wedge.Material = Enum.Material.Glass;
		wedge.Color = tint;
		wedge.Reflectance = 0.35;
		wedge.Transparency = 0.2;
		wedge.Size = new Vector3(0.05 * scale, rng.NextNumber(0.4, 1.5) * scale, rng.NextNumber(0.4, 1.5) * scale);
		const base = CFrame.fromMatrix(start, N, offset.Magnitude > 0.01 ? offset.Unit : up);
		wedge.CFrame = base;
		wedge.Parent = ctx.root;
		const out = offset.Magnitude > 0.01 ? offset.Unit : up;
		const vel = out.mul(rng.NextNumber(5, 15) * scale).add(N.mul(rng.NextNumber(3, 11) * scale)).add(rng.NextUnitVector().mul(2));
		const spin = new Vector3(rng.NextNumber(-7, 7), rng.NextNumber(-7, 7), rng.NextNumber(-7, 7));
		const life = rng.NextNumber(1.2, 1.8);
		ctx.tw.add(
			life,
			(k) => {
				const t = k * life;
				const p = start.add(vel.mul(t)).add(new Vector3(0, -9 * t * t, 0));
				wedge.CFrame = new CFrame(p).mul(base.Rotation).mul(CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t));
				wedge.Transparency = k < 0.6 ? 0.2 : 0.2 + 0.8 * ((k - 0.6) / 0.4);
			},
			() => wedge.Destroy(),
		);
	}
}

/**
 * Retakan ruang ala donghua: udara retak kayak kaca dihantam (celah hitam ke ruang hampa, tepi menyala),
 * melebar bertahap (`stages`, detik sejak muncul), lalu pecah berhamburan (`shatter`) atau menutup lagi (`life`).
 * Bidangnya menghadap kamera pas muncul.
 */
export function spaceCrack(ctx: VfxCtx, at: Vector3, scale = 1, color = WHITE, stages: number[] = [], shatter?: number, life = 3) {
	const P = ctx.origin.PointToWorldSpace(at);
	const [right, up, N] = facing(P);
	const rng = new Random();
	const R = 7 * scale;
	const rays = ctx.q.tier === 0 ? 7 : ctx.q.tier === 1 ? 10 : 13;
	const segs = crackPattern(rng, R, rays, ctx.q.tier >= 1 ? 0.45 : 0.18, ctx.q.tier >= 1, 0.17 * scale);
	const net = crackNet(ctx, segs, P, right, up, N, color, 0.04 * scale);
	const n = stages.size();
	const first = n > 0 ? 0.36 : 1;
	growNet(ctx, net, R * first, 0.14);
	stages.forEach((t, i) => ctx.tw.after(t, () => growNet(ctx, net, R * (first + ((1 - first) * (i + 1)) / n), 0.24)));

	// Lubang hampa di pusat + bintik cahaya bocor dari celah
	const hole = host(ctx, new CFrame(P.add(N.mul(0.05 * scale))));
	hole.Shape = Enum.PartType.Ball;
	hole.Material = Enum.Material.SmoothPlastic;
	hole.Color = Color3.fromRGB(2, 2, 6);
	ctx.tw.add(0.18, (k) => {
		const d = 0.7 * scale * ease("out", k);
		hole.Size = new Vector3(d, d, d);
		hole.Transparency = 0;
	});
	let dust: ParticleEmitter | undefined;
	if (ctx.q.tier >= 1) {
		dust = emitter(ctx, hole, {
			Texture: TEX.spark,
			Color: new ColorSequence(color, Color3.fromRGB(170, 150, 255)),
			Size: seq([0, 0.25 * scale], [1, 0]),
			Transparency: seq([0, 0], [1, 1]),
			Lifetime: new NumberRange(0.6, 1.2),
			Speed: new NumberRange(1.5 * scale, 5 * scale),
			SpreadAngle: new Vector2(180, 180),
			Drag: 1.5,
			Rate: 30 * ctx.q.particles,
		});
		dust.Enabled = true;
	}
	burst(ctx, at, color, 0.6 * scale);

	const close = (dur: number) => {
		if (dust) dust.Enabled = false;
		fadeNet(ctx, net, dur, false);
		ctx.tw.add(dur, (k) => (hole.Transparency = k), () => hole.Destroy());
	};
	if (shatter !== undefined) {
		ctx.tw.after(shatter, () => {
			glassShards(ctx, P, right, up, N, net.r, scale, Color3.fromRGB(226, 232, 255));
			burst(ctx, at, color, 1.4 * scale);
			close(0.22);
		});
	} else {
		ctx.tw.after(life, () => close(0.6));
	}
}

/**
 * Sobekan ruang bekas tebasan: celah hitam memanjang A ke B (paling lebar di tengah), tepi menyala, ada retak kecil
 * di pinggirnya. Kebuka ngikutin arah tebasan, bertahan `life` detik, terus menutup dari ujung ke tengah.
 */
export function rift(ctx: VfxCtx, from: Vector3, to: Vector3, color: Color3, scale = 1, life = 1.6) {
	const A = ctx.origin.PointToWorldSpace(from);
	const B = ctx.origin.PointToWorldSpace(to);
	const len = B.sub(A).Magnitude;
	const dir = B.sub(A).Unit;
	const mid = A.Lerp(B, 0.5);
	const [, , camN] = facing(mid);
	const flat = camN.sub(dir.mul(camN.Dot(dir)));
	const N = flat.Magnitude > 0.01 ? flat.Unit : new Vector3(0, 0, 1);
	const side = dir.Cross(N).Unit;
	const rng = new Random();
	const n = ctx.q.tier === 0 ? 10 : 18;
	const W = math.clamp(len * 0.022, 0.6, 5) * scale;
	const thick = math.max(0.06, W * 0.04);
	const pts: Vector3[] = [];
	for (let i = 0; i <= n; i++) {
		const s = i / n;
		const jitter = i === 0 || i === n ? 0 : rng.NextNumber(-1, 1) * W * 0.35;
		pts.push(A.add(dir.mul(len * s)).add(side.mul(jitter)));
	}
	const segs: Array<{ a: Vector3; b: Vector3; s: number; core: Part; glow: Part }> = [];
	for (let i = 0; i < n; i++) {
		const core = host(ctx, new CFrame(pts[i]));
		core.Material = Enum.Material.SmoothPlastic;
		core.Color = Color3.fromRGB(3, 2, 8);
		const glow = host(ctx, new CFrame(pts[i]));
		glow.Material = Enum.Material.Neon;
		glow.Color = color;
		segs.push({ a: pts[i], b: pts[i + 1], s: (i + 0.5) / n, core, glow });
	}
	// Retak kecil di pinggir sobekan
	const extra: CrackNet[] = [];
	if (ctx.q.tier >= 1) {
		const branches = ctx.q.tier === 2 ? 7 : 4;
		for (let b = 0; b < branches; b++) {
			const s = rng.NextNumber(0.2, 0.8);
			const P = A.add(dir.mul(len * s));
			const bs = crackPattern(rng, W * 3, 3, 0.3, false, W * 0.12);
			const net = crackNet(ctx, bs, P, dir, side, N, color, thick);
			extra.push(net);
			ctx.tw.after(0.1 + s * 0.12, () => growNet(ctx, net, W * 3, 0.2));
		}
	}
	const shape = (open: number, closing: number) => {
		for (const sg of segs) {
			// Lebar: paling lebar di tengah, kebuka ngikutin arah tebasan, nutup dari ujung
			const profile = math.sin(math.pi * sg.s) ** 0.7;
			const reveal = math.clamp(open * 1.4 - sg.s * 0.4, 0, 1);
			const shut = math.clamp(1 - closing * 1.6 + math.abs(sg.s - 0.5) * -1.2 + 0.6, 0, 1);
			const w = W * profile * reveal * shut;
			if (w < 0.02) {
				sg.core.Transparency = 1;
				sg.glow.Transparency = 1;
				continue;
			}
			const l = sg.b.sub(sg.a).Magnitude;
			const m = sg.a.Lerp(sg.b, 0.5);
			const cf = CFrame.lookAt(m, sg.b, N);
			sg.core.CFrame = cf.add(N.mul(thick * 0.6));
			sg.core.Size = new Vector3(w, thick, l + w * 0.6);
			sg.core.Transparency = 0;
			sg.glow.CFrame = cf;
			sg.glow.Size = new Vector3(w * 1.5 + 0.25 * scale, thick, l + w);
			sg.glow.Transparency = 0.1;
		}
	};
	ctx.tw.add(0.2, (k) => shape(ease("out", k), 0));
	if (ctx.q.lights) {
		const h = host(ctx, new CFrame(mid), life + 0.8);
		const l = new Instance("PointLight");
		l.Color = color;
		l.Range = math.min(len * 0.4, 60);
		l.Parent = h;
		ctx.tw.add(life + 0.6, (k) => (l.Brightness = 4 * (1 - k)));
	}
	ctx.tw.after(life, () => {
		for (const net of extra) fadeNet(ctx, net, 0.5, false);
		ctx.tw.add(
			0.55,
			(k) => shape(1, ease("in", k)),
			() => {
				for (const sg of segs) {
					sg.core.Destroy();
					sg.glow.Destroy();
				}
			},
		);
	});
}

/** Serpihan pedang yang masih dijepit (melayang pelan, bercahaya) sampai `life` detik. */
export function shard(ctx: VfxCtx, at: Vector3, color: Color3, life = 10) {
	const P = ctx.origin.PointToWorldSpace(at);
	const p = host(ctx, new CFrame(P), life);
	p.Name = "HeldShard";
	p.Size = new Vector3(0.22, 0.9, 0.08);
	p.Transparency = 0;
	p.Material = Enum.Material.Neon;
	p.Color = color;
	emitter(ctx, p, {
		Texture: TEX.glow,
		Color: new ColorSequence(color),
		Size: seq([0, 1.4], [1, 0]),
		Transparency: seq([0, 0.35], [1, 1]),
		Lifetime: new NumberRange(0.5),
		Rate: 12,
	}).Enabled = true;
	if (ctx.q.lights) {
		const l = new Instance("PointLight");
		l.Color = color;
		l.Range = 8;
		l.Brightness = 1.5;
		l.Parent = p;
	}
	ctx.tw.add(life, (k) => (p.CFrame = new CFrame(P).mul(CFrame.Angles(0.3, k * life * 0.8, 0.5))));
}

/** Pedang pecah: kepingan logam + kepingan qi menyala terlempar dari sepanjang bilah (koordinat dunia). */
export function swordShatter(ctx: VfxCtx, base: Vector3, tip: Vector3, color: Color3) {
	const rng = new Random();
	const n = ctx.q.tier === 0 ? 10 : ctx.q.tier === 1 ? 18 : 28;
	const dir = tip.sub(base);
	for (let i = 0; i < n; i++) {
		const s = rng.NextNumber(0.05, 1);
		const start = base.add(dir.mul(s));
		const glowing = i % 3 === 0;
		const piece = new Instance("WedgePart");
		piece.Name = "Fx";
		piece.Anchored = true;
		piece.CanCollide = false;
		piece.CanQuery = false;
		piece.CanTouch = false;
		piece.CastShadow = false;
		piece.Material = glowing ? Enum.Material.Neon : Enum.Material.Metal;
		piece.Color = glowing ? color : Color3.fromRGB(222, 228, 236);
		piece.Reflectance = glowing ? 0 : 0.45;
		piece.Size = new Vector3(0.04, rng.NextNumber(0.15, 0.55), rng.NextNumber(0.2, 0.7));
		piece.CFrame = new CFrame(start).mul(CFrame.Angles(rng.NextNumber(0, 6.3), rng.NextNumber(0, 6.3), rng.NextNumber(0, 6.3)));
		piece.Parent = ctx.root;
		const vel = rng.NextUnitVector().mul(rng.NextNumber(4, 14)).add(dir.Unit.mul(rng.NextNumber(-2, 8)));
		const spin = new Vector3(rng.NextNumber(-9, 9), rng.NextNumber(-9, 9), rng.NextNumber(-9, 9));
		const start0 = piece.CFrame;
		const life = rng.NextNumber(1.4, 2.2);
		ctx.tw.add(
			life,
			(k) => {
				const t = k * life;
				const p = start.add(vel.mul(t)).add(new Vector3(0, -7 * t * t, 0));
				piece.CFrame = new CFrame(p).mul(start0.Rotation).mul(CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t));
				piece.Transparency = k < 0.7 ? 0 : (k - 0.7) / 0.3;
			},
			() => piece.Destroy(),
		);
	}
	const h = host(ctx, new CFrame(base.Lerp(tip, 0.5)), 1.5);
	emitter(ctx, h, {
		Texture: TEX.spark,
		Color: new ColorSequence(WHITE, color),
		Size: seq([0, 0.5], [1, 0]),
		Lifetime: new NumberRange(0.4, 0.9),
		Speed: new NumberRange(8, 26),
		SpreadAngle: new Vector2(180, 180),
		Drag: 3,
		Shape: Enum.ParticleEmitterShape.Box,
	}).Emit(count(ctx, 40));
}

/** Kilau bintang empat arah di satu titik dunia (ujung pedang). */
export function glint(ctx: VfxCtx, P: Vector3, color: Color3) {
	const [right, up] = facing(P);
	const h = host(ctx, new CFrame(P), 0.6);
	emitter(ctx, h, {
		Texture: TEX.flare,
		Color: new ColorSequence(WHITE, color),
		Size: seq([0, 0.3], [0.3, 2.2], [1, 0]),
		Transparency: seq([0, 0], [1, 1]),
		Lifetime: new NumberRange(0.45),
		Rotation: new NumberRange(0, 90),
	}).Emit(1);
	const arms = [right, up, right.mul(-1), up.mul(-1)];
	arms.forEach((d, i) => {
		const streak = host(ctx, CFrame.lookAt(P, P.add(d)), 0.5);
		streak.Material = Enum.Material.Neon;
		streak.Color = WHITE;
		const reach = i % 2 === 0 ? 2.6 : 1.8;
		ctx.tw.add(0.45, (k) => {
			const e = k < 0.35 ? ease("out", k / 0.35) : 1 - ease("in", (k - 0.35) / 0.65);
			const l = math.max(reach * e, 0.01);
			streak.Size = new Vector3(0.06 * e + 0.01, 0.06 * e + 0.01, l);
			streak.CFrame = CFrame.lookAt(P.add(d.mul(l / 2)), P.add(d.mul(l)));
			streak.Transparency = 0.05 + 0.6 * (1 - e);
		});
	});
}

export function burst(ctx: VfxCtx, at: Vector3, color: Color3, scale = 1) {
	const P = ctx.origin.PointToWorldSpace(at);
	const h = host(ctx, new CFrame(P), 1.8);
	emitter(ctx, h, {
		Texture: TEX.flare,
		Color: new ColorSequence(color),
		Size: seq([0, 2 * scale], [0.2, 7 * scale], [1, 9 * scale]),
		Transparency: seq([0, 0], [1, 1]),
		Lifetime: new NumberRange(0.35),
		Rotation: new NumberRange(0, 360),
	}).Emit(1);
	emitter(ctx, h, {
		Texture: TEX.glow,
		Color: new ColorSequence(color),
		Size: seq([0, 5 * scale], [1, 13 * scale]),
		Transparency: seq([0, 0.3], [1, 1]),
		Lifetime: new NumberRange(0.5),
	}).Emit(1);
	emitter(ctx, h, {
		Texture: TEX.spark,
		Color: new ColorSequence(WHITE, color),
		Size: seq([0, 0.6 * scale], [1, 0]),
		Lifetime: new NumberRange(0.3, 0.7),
		Speed: new NumberRange(25 * scale, 55 * scale),
		SpreadAngle: new Vector2(180, 180),
		Drag: 6,
		Acceleration: new Vector3(0, -20, 0),
	}).Emit(count(ctx, 26));
	if (ctx.q.tier === 2) {
		// Kilatan bintang: garis cahaya tipis memancar sekejap
		const rng = new Random();
		for (let i = 0; i < 6; i++) {
			const d = rng.NextUnitVector();
			const streak = host(ctx, CFrame.lookAt(P, P.add(d)), 0.25);
			streak.Transparency = 0;
			streak.Material = Enum.Material.Neon;
			streak.Color = color;
			ctx.tw.add(0.18, (k) => {
				const len = (3 + 14 * k) * scale;
				streak.Size = new Vector3(0.15 * scale * (1 - k), 0.15 * scale * (1 - k), len);
				streak.CFrame = CFrame.lookAt(P.add(d.mul(len / 2)), P.add(d.mul(len)));
				streak.Transparency = k;
			});
		}
	}
	if (!ctx.q.low) {
		emitter(ctx, h, {
			Texture: TEX.smokeFlip,
			FlipbookLayout: Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode: Enum.ParticleFlipbookMode.OneShot,
			Color: new ColorSequence(color),
			LightEmission: 0.4,
			Size: seq([0, 3 * scale], [1, 8 * scale]),
			Transparency: seq([0, 0.4], [1, 1]),
			Lifetime: new NumberRange(0.8, 1.2),
			Speed: new NumberRange(3, 8),
			SpreadAngle: new Vector2(180, 180),
			Rotation: new NumberRange(0, 360),
		}).Emit(4);
	}
	if (ctx.q.lights) {
		const light = new Instance("PointLight");
		light.Color = color;
		light.Range = math.min(24 * scale, 60);
		light.Parent = h;
		ctx.tw.add(0.35, (k) => (light.Brightness = 5 * (1 - k)));
	}
}

/** Gelombang kejut datar. normal = arah tegak lurus cincin (default ke atas, relatif ke origin). */
export function ring(ctx: VfxCtx, at: Vector3, scale: number, color: Color3, normal = UP) {
	const P = ctx.origin.PointToWorldSpace(at);
	const N = ctx.origin.VectorToWorldSpace(normal).Unit;
	const cf = math.abs(N.Y) > 0.99 ? CFrame.lookAt(P, P.add(N), new Vector3(0, 0, 1)) : CFrame.lookAt(P, P.add(N));
	const h = host(ctx, cf, 1);
	emitter(ctx, h, {
		Texture: TEX.shockRing,
		Color: new ColorSequence(color),
		EmissionDirection: Enum.NormalId.Front,
		Orientation: Enum.ParticleOrientation.VelocityPerpendicular,
		Speed: new NumberRange(0.01),
		Size: seq([0, 0.1], [0.3, scale * 0.75], [1, scale]),
		Transparency: seq([0, 0], [0.6, 0.3], [1, 1]),
		Lifetime: new NumberRange(0.5),
	}).Emit(1);
}

/** Serpihan bercahaya yang jatuh lewat kurva Bezier (from, via, to), ninggalin jejak. Tetap ada sampai cutscene selesai. */
export function fall(ctx: VfxCtx, from: Vector3, via: Vector3, to: Vector3, dur: number, color: Color3) {
	const [P0, P1, P2] = [from, via, to].map((p) => ctx.origin.PointToWorldSpace(p));
	const shard = host(ctx, new CFrame(P0));
	shard.Name = "Shard";
	shard.Size = new Vector3(0.35, 1.4, 0.35);
	shard.Transparency = 0;
	shard.Material = Enum.Material.Neon;
	shard.Color = color;
	const a0 = new Instance("Attachment");
	a0.Position = new Vector3(-0.5, 0, 0);
	a0.Parent = shard;
	const a1 = new Instance("Attachment");
	a1.Position = new Vector3(0.5, 0, 0);
	a1.Parent = shard;
	const trail = new Instance("Trail");
	trail.Attachment0 = a0;
	trail.Attachment1 = a1;
	trail.Lifetime = 0.7;
	trail.LightEmission = 1;
	trail.LightInfluence = 0;
	trail.FaceCamera = true;
	trail.Color = new ColorSequence(WHITE, color);
	trail.Transparency = new NumberSequence(0.1, 1);
	trail.WidthScale = new NumberSequence(1, 0);
	trail.Parent = shard;
	const glow = emitter(ctx, shard, {
		Texture: TEX.glow,
		Color: new ColorSequence(color),
		Size: seq([0, 2.5], [1, 0]),
		Transparency: seq([0, 0.2], [1, 1]),
		Lifetime: new NumberRange(0.6),
		Rate: 40 * ctx.q.particles,
	});
	glow.Enabled = true;
	if (ctx.q.lights) {
		const light = new Instance("PointLight");
		light.Color = color;
		light.Range = 25;
		light.Brightness = 3;
		light.Parent = shard;
	}
	ctx.tw.add(dur, (k) => {
		const p = P0.mul((1 - k) ** 2).add(P1.mul(2 * (1 - k) * k)).add(P2.mul(k * k));
		shard.CFrame = new CFrame(p).mul(CFrame.Angles(k * 40, k * 25, 0));
	});
}

/** Pecahan tanah / logam terlempar + debu melingkar. */
export function debris(ctx: VfxCtx, at: Vector3, scale = 1, color = Color3.fromRGB(236, 232, 224), gravity = 60) {
	const P = ctx.origin.PointToWorldSpace(at);
	const rng = new Random();
	const chunks = ctx.q.low ? 6 : 14;
	for (let i = 0; i < chunks; i++) {
		const s = rng.NextNumber(0.4, 1.2) * scale;
		const chunk = host(ctx, new CFrame(P), 1.4);
		chunk.Size = new Vector3(s, s * 0.6, s);
		chunk.Transparency = 0;
		chunk.Color = color;
		chunk.Material = Enum.Material.Slate;
		const ang = rng.NextNumber(0, math.pi * 2);
		const vel = new Vector3(math.cos(ang) * rng.NextNumber(8, 22), rng.NextNumber(14, 30), math.sin(ang) * rng.NextNumber(8, 22)).mul(scale);
		const spin = new Vector3(rng.NextNumber(-8, 8), rng.NextNumber(-8, 8), rng.NextNumber(-8, 8));
		ctx.tw.add(1.3, (k) => {
			const t = k * 1.3;
			const p = P.add(vel.mul(t)).add(new Vector3(0, -0.5 * gravity * t * t, 0));
			chunk.CFrame = new CFrame(p).mul(CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t));
			chunk.Transparency = k < 0.7 ? 0 : (k - 0.7) / 0.3;
		});
	}
	const dust = host(ctx, new CFrame(P), 2);
	emitter(ctx, dust, {
		Texture: TEX.smokeFlip,
		FlipbookLayout: Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode: Enum.ParticleFlipbookMode.OneShot,
		Shape: Enum.ParticleEmitterShape.Disc,
		ShapeInOut: Enum.ParticleEmitterShapeInOut.Outward,
		Color: new ColorSequence(color),
		LightEmission: 0,
		LightInfluence: 1,
		Size: seq([0, 3 * scale], [1, 9 * scale]),
		Transparency: seq([0, 0.35], [1, 1]),
		Lifetime: new NumberRange(1, 1.6),
		Speed: new NumberRange(18 * scale, 28 * scale),
		Drag: 5,
		Rotation: new NumberRange(0, 360),
	}).Emit(count(ctx, 18));
}

/** Semua part di folder set `target` terhempas menjauh dari titik `from` lalu hilang. */
export function collapse(ctx: VfxCtx, target: string, from: Vector3, dur = 2.5) {
	const folder = ctx.root.FindFirstChild(target);
	if (!folder) return;
	const F = ctx.origin.PointToWorldSpace(from);
	const rng = new Random();
	for (const d of folder.GetDescendants()) {
		if (!d.IsA("BasePart")) continue;
		const P = d.Position;
		const dir = P.sub(F).Unit.add(rng.NextUnitVector().mul(0.35)).Unit;
		const dist = rng.NextNumber(60, 160);
		const spin = rng.NextNumber(-6, 6);
		const t0 = d.Transparency;
		ctx.tw.add(dur, (k) => {
			const e = ease("expoOut", k);
			d.CFrame = new CFrame(P.add(dir.mul(dist * e))).mul(CFrame.Angles(spin * e, spin * 0.6 * e, 0));
			d.Transparency = k < 0.35 ? t0 : t0 + (1 - t0) * ((k - 0.35) / 0.65);
		});
	}
	ctx.tw.after(dur, () => folder.Destroy());
}

/** Satu bayangan (afterimage) aktor: salinan part badan, bercahaya, memudar. */
export function ghost(ctx: VfxCtx, actor: Actor) {
	const parts: BasePart[] = [];
	for (const p of actor.parts()) {
		if (p.Parent === undefined) continue;
		const g = p.Clone();
		g.ClearAllChildren();
		g.Anchored = true;
		g.Material = Enum.Material.Neon;
		g.Color = actor.ghostColor;
		g.Transparency = 0.55;
		g.CastShadow = false;
		g.Parent = ctx.root;
		parts.push(g);
	}
	actor.liveGhosts += 1;
	ctx.tw.add(
		0.3,
		(k) => {
			for (const g of parts) g.Transparency = 0.55 + 0.45 * k;
		},
		() => {
			for (const g of parts) g.Destroy();
			actor.liveGhosts -= 1;
		},
	);
}
