// VFX cutscene: tebasan bulan sabit, gelombang tebasan raksasa, sinar tebasan emas raksasa (cleave), kilatan pedang
// melesat, energi ngumpul, ledakan cahaya, gelombang kejut, petir, retakan ruang/langit bergaya petir (sobekan ruang
// bekas tebasan), tanah pecah 3D, serpihan jatuh, pedang pecah, kilau pedang, debu, pasukan terhempas, afterimage.
// Pakai tekstur sendiri yang udah di-upload + partikel (murah, bisa di-batch GPU). Jumlah partikel dikali q.particles,
// lapisan ekstra cuma di tier tinggi.

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

// ---------- Retakan bergaya petir (langit / ruang pecah), tanah pecah 3D ----------
// Gaya dari referensi donghua (Swallowed Star): retakan putih panas bercabang kayak petir, pinggirnya cahaya oranye
// emas, sinar bocor dari celahnya, pecahan kaca berjatuhan. Satu retakan = 2 Beam bertekstur, jadi murah.

/** Putih panas (inti cahaya). */
const HOT = Color3.fromRGB(255, 246, 222);
/** Pinggiran cahaya hangat (oranye emas) di belakang retakan dan sinar. */
const EMBER = Color3.fromRGB(255, 160, 70);

function att(parent: Instance, world: Vector3): Attachment {
	const a = new Instance("Attachment");
	a.Parent = parent;
	a.WorldPosition = world;
	return a;
}

/** Beam lurus ngadep kamera di antara dua attachment (cahaya murni, gak kena lampu). */
function beamOf(parent: Instance, a0: Attachment, a1: Attachment, props: Partial<WritableInstanceProperties<Beam>>): Beam {
	const b = new Instance("Beam");
	b.Attachment0 = a0;
	b.Attachment1 = a1;
	b.FaceCamera = true;
	b.LightEmission = 1;
	b.LightInfluence = 0;
	b.Segments = 1;
	for (const [k, v] of pairs(props as Record<string, unknown>)) (b as unknown as Record<string, unknown>)[k] = v;
	b.Parent = parent;
	return b;
}

/** Basis bidang yang menghadap kamera di titik P: [kanan, atas, normal]. */
function facing(P: Vector3): [Vector3, Vector3, Vector3] {
	const cam = Workspace.CurrentCamera;
	const toCam = cam ? cam.CFrame.Position.sub(P) : new Vector3(0, 0, 1);
	const N = toCam.Magnitude > 0.01 ? toCam.Unit : new Vector3(0, 0, 1);
	const basis = CFrame.lookAt(P, P.add(N));
	return [basis.RightVector, basis.UpVector, N];
}

/** Satu retakan petir yang merambat dari `from` ke `to`. */
interface Bolt {
	from: Vector3;
	to: Vector3;
	tip: Attachment;
	crack: Beam;
	haze: Beam;
	w: number;
	/** Seberapa jauh udah merambat (0..1). */
	f: number;
}

function bolt(holder: Part, rng: Random, from: Vector3, to: Vector3, w: number, glow: Color3): Bolt {
	const a0 = att(holder, from);
	const tip = att(holder, from);
	// Tekstur petir diulang per stud (Wrap), jadi pas merambat cabangnya kebuka, bukan ketarik
	const crack = beamOf(holder, a0, tip, {
		Texture: TEX.lightning,
		TextureMode: Enum.TextureMode.Wrap,
		TextureLength: w * rng.NextNumber(2.6, 3.8),
		Width0: w,
		Width1: w * 0.7,
		Brightness: 3,
		Color: new ColorSequence(HOT),
	});
	const haze = beamOf(holder, a0, tip, {
		Texture: TEX.glow,
		TextureMode: Enum.TextureMode.Stretch,
		Width0: w * 0.8,
		Width1: w * 0.5,
		Brightness: 2,
		Color: new ColorSequence(glow),
		Transparency: new NumberSequence(0.4),
	});
	return { from, to, tip, crack, haze, w, f: 0 };
}

function reach(b: Bolt, f: number) {
	b.f = f;
	b.tip.WorldPosition = b.from.Lerp(b.to, f);
}

/** Terang retakan: a = 1 penuh, 0 hilang. `flicker` = kedip acak kayak petir pas baru retak. */
function shade(bolts: Bolt[], a: number, widthMul: number, flicker: boolean) {
	for (const b of bolts) {
		const t = math.clamp(1 - a + (flicker ? math.random() * 0.6 * a : 0), 0, 1);
		// Ujung retakan memudar, gak kepotong kotak
		b.crack.Transparency = seq([0, t], [0.8, t], [1, 1]);
		b.haze.Transparency = new NumberSequence(0.4 + 0.6 * t);
		b.crack.Width0 = b.w * widthMul;
		b.crack.Width1 = b.w * 0.7 * widthMul;
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
 * Retakan ruang ala donghua: udara retak dari satu titik kayak kaca dihantam petir (retakan putih panas bercabang,
 * cahaya di pusatnya), melebar bertahap (`stages`, detik sejak muncul), lalu pecah berhamburan (`shatter`) atau
 * meredup sampai hilang (`life`). Bidangnya menghadap kamera pas muncul.
 */
export function spaceCrack(ctx: VfxCtx, at: Vector3, scale = 1, color = WHITE, stages: number[] = [], shatter?: number, life = 3) {
	const P = ctx.origin.PointToWorldSpace(at);
	const [right, up, N] = facing(P);
	const rng = new Random();
	const R = 7 * scale;
	const holder = host(ctx, new CFrame(P));
	const rays = ctx.q.tier === 0 ? 6 : ctx.q.tier === 1 ? 8 : 11;
	const bolts: Bolt[] = [];
	for (let r = 0; r < rays; r++) {
		const ang = (r / rays) * math.pi * 2 + rng.NextNumber(-0.25, 0.25);
		// Sedikit maju-mundur dari bidang biar ada kedalaman pas kamera geser
		const d = right.mul(math.cos(ang)).add(up.mul(math.sin(ang))).add(N.mul(rng.NextNumber(-0.2, 0.2))).Unit;
		bolts.push(bolt(holder, rng, P, P.add(d.mul(R * rng.NextNumber(0.6, 1))), R * rng.NextNumber(0.3, 0.45), color));
	}
	const n = stages.size();
	const first = n > 0 ? 0.36 : 1;
	let f = 0;
	const grow = (to: number, dur: number) => {
		const from = f;
		ctx.tw.add(dur, (k) => {
			f = from + (to - from) * ease("out", k);
			for (const b of bolts) reach(b, f);
			shade(bolts, 1, 1, k < 0.7);
		});
	};
	grow(first, 0.14);
	stages.forEach((t, i) => ctx.tw.after(t, () => grow(first + ((1 - first) * (i + 1)) / n, 0.24)));

	// Cahaya di pusat retakan (kecil, biar tangan/bilah di depannya gak ketutup silau) + bintik cahaya bocor dari celah
	const glow = beamOf(holder, att(holder, P.sub(right.mul(R * 0.2))), att(holder, P.add(right.mul(R * 0.2))), {
		Texture: TEX.glow,
		TextureMode: Enum.TextureMode.Stretch,
		Width0: R * 0.4,
		Width1: R * 0.4,
		Brightness: 2,
		Color: new ColorSequence(color),
		Transparency: new NumberSequence(0.2),
	});
	let dust: ParticleEmitter | undefined;
	if (ctx.q.tier >= 1) {
		dust = emitter(ctx, holder, {
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
	// Retakan kecil buat close-up gak pakai kilatan bintang (bisa nutup satu layar)
	if (scale >= 0.6) burst(ctx, at, color, 0.6 * scale);

	const close = (dur: number) => {
		if (dust) dust.Enabled = false;
		ctx.tw.add(
			dur,
			(k) => {
				shade(bolts, 1 - k, 1 - 0.4 * k, false);
				glow.Transparency = new NumberSequence(0.2 + 0.8 * k);
			},
			() => holder.Destroy(),
		);
	};
	if (shatter !== undefined) {
		ctx.tw.after(shatter, () => {
			glassShards(ctx, P, right, up, N, R * math.max(f, 0.3), scale, Color3.fromRGB(226, 232, 255));
			burst(ctx, at, color, 1.4 * scale);
			close(0.22);
		});
	} else {
		ctx.tw.after(life, () => close(0.6));
	}
}

/**
 * Sobekan ruang bekas tebasan: retakan petir di sepanjang jalur tebasan (merambat dari tengah ke dua ujung), cabang
 * retak menjalar ke samping kayak langit pecah (sebagian maju/mundur biar 3D), sinar bocor dari celahnya, pecahan kaca
 * berjatuhan. Bertahan `life` detik lalu meredup sampai hilang total.
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
	const holder = host(ctx, new CFrame(mid));
	const W = math.clamp(len * 0.06, 1.2, 14) * scale;
	const main = [bolt(holder, rng, mid, A, W, color), bolt(holder, rng, mid, B, W, color)];
	const branches: Array<[Bolt, number]> = [];
	const n = ctx.q.tier === 0 ? 4 : ctx.q.tier === 1 ? 7 : 11;
	for (let i = 0; i < n; i++) {
		const s = rng.NextNumber(0.08, 0.92);
		const ang = rng.NextNumber(-0.75, 0.75);
		const d = side
			.mul((i % 2 === 0 ? 1 : -1) * math.cos(ang))
			.add(dir.mul(math.sin(ang)))
			.add(N.mul(rng.NextNumber(-0.35, 0.35))).Unit;
		const root = A.Lerp(B, s).add(N.mul(rng.NextNumber(-0.5, 0.5) * W));
		const l = len * rng.NextNumber(0.1, 0.26) * (1.15 - math.abs(s - 0.5));
		// Cabang dekat tengah retak duluan, makin ke ujung makin telat (kayak retaknya menjalar)
		branches.push([bolt(holder, rng, root, root.add(d.mul(l)), W * rng.NextNumber(0.45, 0.8), color), math.abs(s - 0.5) * 0.3 + rng.NextNumber(0, 0.06)]);
	}
	const all = [...main, ...branches.map(([b]) => b)];

	// Sinar bocor dari celah, condong ke arah kamera (kerasa volume)
	const rays: Beam[] = [];
	if (ctx.q.tier >= 1) {
		const nr = ctx.q.tier === 2 ? 6 : 3;
		for (let i = 0; i < nr; i++) {
			const P = A.Lerp(B, rng.NextNumber(0.15, 0.85));
			const d = side
				.mul(i % 2 === 0 ? 0.6 : -0.6)
				.add(N.mul(0.8))
				.add(rng.NextUnitVector().mul(0.25)).Unit;
			const L = W * rng.NextNumber(2.5, 4);
			rays.push(
				beamOf(holder, att(holder, P.sub(d.mul(L * 0.3))), att(holder, P.add(d.mul(L))), {
					Texture: TEX.glow,
					TextureMode: Enum.TextureMode.Stretch,
					Width0: W * 0.35,
					Width1: W * 1.3,
					Brightness: 1.5,
					Color: new ColorSequence(color),
					Transparency: new NumberSequence(1),
				}),
			);
		}
	}
	const rayLook = (t: number) => seq([0, 1], [0.25, t], [1, 1]);

	ctx.tw.add(0.5, (k) => {
		const t = k * 0.5;
		for (const b of main) reach(b, ease("expoOut", math.clamp(t / 0.18, 0, 1)));
		for (const [b, delay] of branches) reach(b, ease("out", math.clamp((t - delay) / 0.22, 0, 1)));
		shade(all, 1, 1, t < 0.3);
		const ray = rayLook(0.5 + 0.5 * (1 - math.clamp(t / 0.2, 0, 1)));
		for (const r of rays) r.Transparency = ray;
	});
	if (ctx.q.tier >= 1) {
		ctx.tw.after(0.12, () => {
			const tint = Color3.fromRGB(255, 238, 205);
			for (const s of [0.32, 0.68]) glassShards(ctx, A.Lerp(B, s), dir, side, N, W * 0.9, math.max(W / 6, 0.25), tint);
		});
	}
	if (ctx.q.lights) {
		const h = host(ctx, new CFrame(mid), life + 0.8);
		const l = new Instance("PointLight");
		l.Color = color;
		l.Range = math.min(len * 0.4, 60);
		l.Parent = h;
		ctx.tw.add(life + 0.6, (k) => (l.Brightness = 4 * (1 - k)));
	}
	ctx.tw.after(life, () =>
		ctx.tw.add(
			0.6,
			(k) => {
				shade(all, 1 - ease("in", k), 1 - 0.5 * k, false);
				const ray = rayLook(0.5 + 0.5 * k);
				for (const r of rays) r.Transparency = ray;
			},
			() => holder.Destroy(),
		),
	);
}

/** Material + warna tanah di titik P. Part set cutscene gak bisa di-raycast (CanQuery mati), jadi dicari dari kotaknya. */
function groundAt(ctx: VfxCtx, P: Vector3): [Enum.Material, Color3] {
	let best: BasePart | undefined;
	let bestGap = math.huge;
	for (const d of ctx.root.GetDescendants()) {
		if (!d.IsA("BasePart") || d.Name === "Fx" || d.Transparency > 0.9 || d.Size.Magnitude < 8) continue;
		const lp = d.CFrame.PointToObjectSpace(P);
		const h = d.Size.div(2);
		if (math.abs(lp.X) > h.X + 0.6 || math.abs(lp.Y) > h.Y + 0.6 || math.abs(lp.Z) > h.Z + 0.6) continue;
		const cf = d.CFrame;
		const top = cf.Y + math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z;
		const gap = math.abs(top - P.Y);
		if (gap < bestGap) {
			bestGap = gap;
			best = d;
		}
	}
	return best ? [best.Material, best.Color] : [Enum.Material.Slate, Color3.fromRGB(120, 116, 110)];
}

interface Plate {
	p: Part;
	from: CFrame;
	to: CFrame;
	delay: number;
}

/**
 * Tanah pecah 3D ala donghua: lempeng tanah (material + warna ikut tanah di situ) terangkat miring melingkar kayak
 * kawah, celah di antaranya nyala lalu mendingin. Habis `life` detik lempengnya turun lagi dan hilang total
 * (gak ninggalin bekas hitam).
 */
export function cracks(ctx: VfxCtx, at: Vector3, scale = 1, glow?: Color3, life = 1.8) {
	const C = ctx.origin.PointToWorldSpace(at);
	const F = new CFrame(C).mul(ctx.origin.Rotation);
	const upW = F.UpVector;
	const [mat, col] = groundAt(ctx, C);
	const rng = new Random();
	const rings = ctx.q.tier === 0 ? 2 : ctx.q.tier === 1 ? 3 : 4;
	const edges = [1.1, 2.6, 4.4, 6.4, 8.6];
	const sectors = [6, 9, 12, 15];
	const tilts = [
		[20, 32],
		[12, 22],
		[6, 14],
		[2, 8],
	];
	const outer = edges[rings] * scale;
	const seam = glow ?? Color3.fromRGB(255, 170, 90);

	// Dasar di bawah lempeng (cuma kelihatan di celah): nyala dulu terus mendingin jadi gelap
	const pit = host(ctx, F.mul(new CFrame(0, -0.02, 0)).mul(CFrame.Angles(0, 0, math.pi / 2)));
	pit.Shape = Enum.PartType.Cylinder;
	pit.Material = Enum.Material.Neon;
	pit.Color = seam;
	pit.Size = new Vector3(0.12, outer * 1.94, outer * 1.94);
	pit.Transparency = 0;

	const plates: Plate[] = [];
	for (let ring = 0; ring < rings; ring++) {
		const r0 = edges[ring] * scale;
		const r1 = edges[ring + 1] * scale;
		const n = sectors[ring];
		const off = rng.NextNumber(0, math.pi * 2);
		const bounds: number[] = [];
		for (let i = 0; i <= n; i++) bounds.push(off + ((i + (i === 0 || i === n ? 0 : rng.NextNumber(-0.25, 0.25))) / n) * math.pi * 2);
		for (let i = 0; i < n; i++) {
			const a0 = bounds[i];
			const a1 = bounds[i + 1];
			const am = (a0 + a1) / 2;
			const rm = (r0 + r1) / 2;
			const width = 2 * rm * math.sin((a1 - a0) / 2) * rng.NextNumber(0.88, 0.96);
			const depth = (r1 - r0) * rng.NextNumber(0.86, 0.94);
			const thick = rng.NextNumber(0.5, 0.85) * math.max(scale, 0.6);
			const radial = new Vector3(math.cos(am), 0, math.sin(am));
			const center = radial.mul(rm);
			const psi = math.rad(rng.NextNumber(tilts[ring][0], tilts[ring][1]));
			// Hadap keluar (LookVector = arah radial). Dimiringin: pinggir dalam terangkat, pinggir luar napak tanah
			const flat = F.mul(CFrame.lookAt(center, center.add(radial)));
			const tilted = flat.mul(CFrame.Angles(-psi, math.rad(rng.NextNumber(-5, 5)), math.rad(rng.NextNumber(-6, 6))));
			const p = host(ctx, flat.add(upW.mul(-thick / 2 - 0.3)));
			p.Material = mat;
			p.Color = col.Lerp(Color3.fromRGB(60, 56, 52), rng.NextNumber(0, 0.18));
			p.Size = new Vector3(width, thick, depth);
			p.Transparency = 0;
			p.CastShadow = ctx.q.tier >= 1;
			plates.push({
				p,
				from: flat.add(upW.mul(-thick / 2 - 0.3)),
				to: tilted.add(upW.mul((depth / 2) * math.sin(psi) - thick / 2 + 0.06)),
				delay: ring * 0.025,
			});
		}
	}
	// Lempeng nongol dari dalam ke luar
	ctx.tw.add(0.2, (k) => {
		const t = k * 0.2;
		for (const pl of plates) pl.p.CFrame = pl.from.Lerp(pl.to, ease("out", math.clamp((t - pl.delay) / 0.12, 0, 1)));
	});
	const cool = Color3.fromRGB(28, 24, 26);
	ctx.tw.add(1.2, (k) => (pit.Color = seam.Lerp(cool, ease("out", k))));
	if (ctx.q.lights && glow) {
		const h = host(ctx, new CFrame(C.add(upW)), 2.5);
		const l = new Instance("PointLight");
		l.Color = glow;
		l.Range = 14 * scale;
		l.Parent = h;
		ctx.tw.add(2.4, (k) => (l.Brightness = 3 * (1 - k)));
	}
	// Habis itu turun lagi + memudar, terus dihapus semua
	ctx.tw.after(life, () =>
		ctx.tw.add(
			0.7,
			(k) => {
				const e = ease("in", k);
				for (const pl of plates) {
					pl.p.CFrame = pl.to.Lerp(pl.from, e);
					pl.p.Transparency = e;
				}
				pit.Transparency = e;
			},
			() => {
				for (const pl of plates) pl.p.Destroy();
				pit.Destroy();
			},
		),
	);
}

/**
 * Kilatan pedang melesat (garis cahaya tipis) dari `from` ke `to`: kepalanya berkilau, ekornya nyusul di belakang,
 * makin cepat (gaya "garis tipis di kegelapan" referensi). Habis nyampe langsung hilang.
 */
export function streak(ctx: VfxCtx, from: Vector3, to: Vector3, color: Color3, scale = 1, dur = 0.3) {
	const A = ctx.origin.PointToWorldSpace(from);
	const B = ctx.origin.PointToWorldSpace(to);
	const holder = host(ctx, new CFrame(A), dur + 0.6);
	const tail = att(holder, A);
	const head = att(holder, A);
	const core = beamOf(holder, tail, head, { Width0: 0.2 * scale, Width1: 0.9 * scale, Brightness: 5, Color: new ColorSequence(WHITE) });
	const glow = beamOf(holder, tail, head, {
		Texture: TEX.glow,
		TextureMode: Enum.TextureMode.Stretch,
		Width0: 1.2 * scale,
		Width1: 5 * scale,
		Brightness: 2,
		Color: new ColorSequence(color),
		Transparency: new NumberSequence(0.25),
	});
	// Kilau di kepala: quad tekstur flare, sisinya diarahin ke kanan kamera biar selalu kelihatan penuh
	const f0 = att(holder, A);
	const f1 = att(holder, A);
	const size = 9 * scale;
	const flare = beamOf(holder, f0, f1, {
		Texture: TEX.flare,
		TextureMode: Enum.TextureMode.Stretch,
		Width0: size,
		Width1: size,
		Brightness: 4,
		Color: new ColorSequence(WHITE, color),
	});
	const place = (h: Vector3) => {
		const [right] = facing(h);
		f0.WorldPosition = h.sub(right.mul(size / 2));
		f1.WorldPosition = h.add(right.mul(size / 2));
	};
	ctx.tw.add(
		dur,
		(k) => {
			const e = ease("in", k);
			const h = A.Lerp(B, e);
			head.WorldPosition = h;
			tail.WorldPosition = A.Lerp(B, math.max(0, e - 0.6));
			place(h);
		},
		() => {
			const t0 = tail.WorldPosition;
			ctx.tw.add(
				0.22,
				(k) => {
					tail.WorldPosition = t0.Lerp(B, ease("out", k));
					const tr = new NumberSequence(k);
					core.Transparency = tr;
					glow.Transparency = new NumberSequence(0.25 + 0.75 * k);
					flare.Transparency = tr;
				},
				() => holder.Destroy(),
			);
		},
	);
}

/**
 * Tebasan cahaya raksasa ala donghua: garis tipis menyala dari tengah ke dua ujung, diam sebentar (`delay`), terus
 * meledak jadi sinar emas tebal (inti putih panas, serat energi mengalir, sinar memancar, percikan, kabut), ditahan
 * `hold` detik lalu menipis sampai hilang. Ujungnya dilebihin biar kerasa nembus sampai ujung langit.
 */
export function cleave(ctx: VfxCtx, from: Vector3, to: Vector3, color: Color3, scale = 1, delay = 0.2, hold = 1) {
	const A0 = ctx.origin.PointToWorldSpace(from);
	const B0 = ctx.origin.PointToWorldSpace(to);
	const len = B0.sub(A0).Magnitude;
	const dir = B0.sub(A0).Unit;
	const mid = A0.Lerp(B0, 0.5);
	const A = mid.sub(dir.mul(len * 0.62));
	const B = mid.add(dir.mul(len * 0.62));
	const [, , camN] = facing(mid);
	const flatN = camN.sub(dir.mul(camN.Dot(dir)));
	const N = flatN.Magnitude > 0.01 ? flatN.Unit : new Vector3(0, 0, 1);
	const side = dir.Cross(N).Unit;
	const rng = new Random();
	const W = 6 * scale;
	const total = delay + hold + 1;
	const holder = host(ctx, new CFrame(mid), total + 0.3);
	const a0 = att(holder, mid);
	const a1 = att(holder, mid);
	const layer = (props: Partial<WritableInstanceProperties<Beam>>) =>
		beamOf(holder, a0, a1, { Texture: TEX.glow, TextureMode: Enum.TextureMode.Stretch, Segments: 4, ...props });
	const haze = layer({ Brightness: 1.5, Color: new ColorSequence(EMBER), Transparency: new NumberSequence(1) });
	const body = layer({ Brightness: 3, Color: new ColorSequence(color) });
	// Inti putih panas: polos (tajam), ujungnya dipudarin
	const core = beamOf(holder, a0, a1, { Brightness: 6, Segments: 4, Color: new ColorSequence(WHITE) });
	const ends = (t: number) => seq([0, 1], [0.1, t], [0.9, t], [1, 1]);
	const setW = (b: Beam, w: number) => {
		b.Width0 = w;
		b.Width1 = w;
	};

	// Serat energi: tekstur petir yang mengalir sepanjang sinar, tiap serat geser dikit dari sumbu
	interface Strand {
		beam: Beam;
		s0: Attachment;
		s1: Attachment;
		off: number;
		w: number;
		ph: number;
	}
	const strands: Strand[] = [];
	const ns = ctx.q.tier === 0 ? 2 : ctx.q.tier === 1 ? 3 : 5;
	for (let i = 0; i < ns; i++) {
		const s0 = att(holder, mid);
		const s1 = att(holder, mid);
		const beam = beamOf(holder, s0, s1, {
			Texture: TEX.lightning,
			TextureMode: Enum.TextureMode.Wrap,
			TextureLength: W * rng.NextNumber(5, 9),
			TextureSpeed: rng.NextNumber(1.5, 3.2),
			Brightness: 3,
			Color: new ColorSequence(i % 2 === 0 ? HOT : color),
			Transparency: new NumberSequence(1),
		});
		strands.push({ beam, s0, s1, off: rng.NextNumber(-0.35, 0.35) * W, w: W * rng.NextNumber(1.2, 2), ph: rng.NextNumber(0, 6) });
	}

	// Garis tipis dulu: dari tengah ke dua ujung, kedip halus sambil nunggu meledak
	ctx.tw.add(0.12, (k) => {
		const e = ease("expoOut", k);
		a0.WorldPosition = mid.Lerp(A0, e);
		a1.WorldPosition = mid.Lerp(B0, e);
	});
	setW(core, 0.35 * scale);
	setW(body, 2 * scale);
	ctx.tw.add(delay, (k) => {
		core.Transparency = ends(math.random() * 0.25);
		setW(core, (0.35 + 0.25 * k) * scale);
	});

	ctx.tw.after(delay, () => {
		// Meledak: melebar cepat, ujung nembus jauh
		const pulse = (t: number) => 1 + 0.06 * math.sin(t * 38) + 0.04 * math.sin(t * 61);
		ctx.tw.add(hold, (k) => {
			const t = k * hold;
			const open = ease("expoOut", math.clamp(t / 0.1, 0, 1));
			a0.WorldPosition = A0.Lerp(A, open);
			a1.WorldPosition = B0.Lerp(B, open);
			const p = pulse(t);
			setW(core, (0.35 * scale + (W * 0.5 - 0.35 * scale) * open) * p);
			setW(body, (2 * scale + (W * 2.6 - 2 * scale) * open) * p);
			setW(haze, W * 5 * open);
			haze.Transparency = new NumberSequence(1 - 0.45 * open);
			core.Transparency = ends(0);
			for (const s of strands) {
				const wob = math.sin(t * 9 + s.ph) * W * 0.12;
				const o = side.mul((s.off + wob) * open);
				s.s0.WorldPosition = a0.WorldPosition.add(o);
				s.s1.WorldPosition = a1.WorldPosition.add(o);
				setW(s.beam, s.w * open);
				s.beam.Transparency = ends(0.15 + 0.2 * math.random());
			}
		});

		// Sinar memancar dari garis tebasan, condong ke kamera
		const rays: Beam[] = [];
		if (ctx.q.tier >= 1) {
			const nr = ctx.q.tier === 2 ? 10 : 6;
			for (let i = 0; i < nr; i++) {
				const P = A0.Lerp(B0, rng.NextNumber(0.12, 0.88));
				const d = side
					.mul(i % 2 === 0 ? 1 : -1)
					.add(N.mul(0.35))
					.add(dir.mul(rng.NextNumber(-0.3, 0.3))).Unit;
				const L = W * rng.NextNumber(4, 7);
				rays.push(
					beamOf(holder, att(holder, P.sub(d.mul(L * 0.25))), att(holder, P.add(d.mul(L))), {
						Texture: TEX.glow,
						TextureMode: Enum.TextureMode.Stretch,
						Width0: W * 0.5,
						Width1: W * 1.6,
						Brightness: 1.5,
						Color: new ColorSequence(Color3.fromRGB(255, 214, 150)),
						Transparency: new NumberSequence(1),
					}),
				);
			}
		}
		ctx.tw.add(0.9, (k) => {
			const tr = seq([0, 1], [0.2, 0.45 + 0.55 * ease("in", k)], [1, 1]);
			for (const r of rays) r.Transparency = tr;
		});

		// Percikan + kabut di sepanjang garis
		const box = host(ctx, CFrame.lookAt(mid, B0), hold + 2);
		box.Size = new Vector3(W, W, len);
		const sparks = emitter(ctx, box, {
			Texture: TEX.spark,
			Shape: Enum.ParticleEmitterShape.Box,
			ShapeStyle: Enum.ParticleEmitterShapeStyle.Volume,
			Color: new ColorSequence(WHITE, color),
			Size: seq([0, 0.9 * scale], [1, 0]),
			Lifetime: new NumberRange(0.5, 1.1),
			Speed: new NumberRange(8 * scale, 30 * scale),
			SpreadAngle: new Vector2(180, 180),
			Drag: 2.5,
			Acceleration: new Vector3(0, -6, 0),
			Rate: 90 * ctx.q.particles,
		});
		sparks.Emit(count(ctx, 140));
		sparks.Enabled = true;
		ctx.tw.after(hold, () => (sparks.Enabled = false));
		if (ctx.q.tier >= 1) {
			emitter(ctx, box, {
				Texture: TEX.smokeFlip,
				FlipbookLayout: Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode: Enum.ParticleFlipbookMode.OneShot,
				Shape: Enum.ParticleEmitterShape.Box,
				ShapeStyle: Enum.ParticleEmitterShapeStyle.Volume,
				Color: new ColorSequence(Color3.fromRGB(255, 232, 196)),
				LightEmission: 0.4,
				Size: seq([0, 6 * scale], [1, 18 * scale]),
				Transparency: seq([0, 0.5], [1, 1]),
				Lifetime: new NumberRange(1, 1.6),
				Speed: new NumberRange(2, 6),
				SpreadAngle: new Vector2(180, 180),
				Rotation: new NumberRange(0, 360),
			}).Emit(count(ctx, 26));
		}
		if (ctx.q.lights) {
			const l = new Instance("PointLight");
			l.Color = color;
			l.Range = 60;
			l.Parent = holder;
			ctx.tw.add(hold + 0.9, (k) => (l.Brightness = 10 * (1 - k)));
		}

		// Menipis jadi garis, terus hilang
		ctx.tw.after(hold, () =>
			ctx.tw.add(0.9, (k) => {
				const e = ease("in", k);
				const tr = ends(e);
				setW(core, W * 0.5 * (1 - 0.85 * e));
				setW(body, W * 2.6 * (1 - 0.85 * e));
				setW(haze, W * 5 * (1 - 0.5 * e));
				core.Transparency = tr;
				body.Transparency = tr;
				haze.Transparency = new NumberSequence(0.55 + 0.45 * e);
				const st = ends(math.clamp(e * 1.8, 0, 1));
				for (const s of strands) s.beam.Transparency = st;
			}),
		);
	});
}

/**
 * Energi ngumpul ke ujung pedang sebelum tebasan besar: butiran cahaya ketarik masuk dari bola besar,
 * pusaran berputar makin besar. `at` dipanggil tiap frame biar ngikutin pedang.
 */
export function charge(ctx: VfxCtx, at: () => Vector3 | undefined, dur: number, color: Color3, scale = 1) {
	const P = at();
	if (!P) return;
	const R = 9 * scale;
	const shell = host(ctx, new CFrame(P), dur + 0.8);
	shell.Shape = Enum.PartType.Ball;
	shell.Size = new Vector3(R * 2, R * 2, R * 2);
	const motes = emitter(ctx, shell, {
		Texture: TEX.glow,
		Shape: Enum.ParticleEmitterShape.Sphere,
		ShapeStyle: Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut: Enum.ParticleEmitterShapeInOut.Inward,
		Orientation: Enum.ParticleOrientation.VelocityParallel,
		Squash: seq([0, 2], [1, 2]),
		Color: new ColorSequence(color, WHITE),
		Size: seq([0, 0.15 * scale], [0.7, 0.45 * scale], [1, 0]),
		Transparency: seq([0, 1], [0.25, 0.1], [1, 0]),
		Lifetime: new NumberRange(0.5),
		Speed: new NumberRange(R / 0.5),
		Rate: 90 * ctx.q.particles,
	});
	motes.Enabled = true;
	if (ctx.q.tier >= 1) {
		emitter(ctx, shell, {
			Texture: TEX.swirl,
			LockedToPart: true,
			Color: new ColorSequence(color),
			Size: seq([0, 1 * scale], [1, 5 * scale]),
			Transparency: seq([0, 1], [0.3, 0.35], [0.85, 0.5], [1, 1]),
			Lifetime: new NumberRange(dur),
			Rotation: new NumberRange(0, 360),
			RotSpeed: new NumberRange(-420),
		}).Emit(1);
	}
	ctx.tw.add(
		dur,
		() => {
			const p = at();
			if (p) shell.CFrame = new CFrame(p);
		},
		() => (motes.Enabled = false),
	);
}

/** Debu cahaya beku: titik-titik cahaya kecil yang diem melayang di udara (momen waktu berhenti). */
export function motes(ctx: VfxCtx, at: Vector3, scale = 1, color = WHITE, life = 6) {
	const P = ctx.origin.PointToWorldSpace(at);
	const h = host(ctx, new CFrame(P), life + 1);
	h.Shape = Enum.PartType.Ball;
	h.Size = new Vector3(3, 3, 3).mul(scale);
	emitter(ctx, h, {
		Texture: TEX.glow,
		Shape: Enum.ParticleEmitterShape.Sphere,
		ShapeStyle: Enum.ParticleEmitterShapeStyle.Volume,
		Color: new ColorSequence(color),
		Size: seq([0, 0.05 * scale], [0.5, 0.09 * scale], [1, 0.05 * scale]),
		Transparency: seq([0, 1], [0.08, 0.15], [0.9, 0.3], [1, 1]),
		Lifetime: new NumberRange(life),
		Speed: new NumberRange(0.02, 0.08),
		SpreadAngle: new Vector2(180, 180),
	}).Emit(count(ctx, 40));
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
