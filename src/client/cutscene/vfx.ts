// VFX cutscene: tebasan bulan sabit, gelombang tebasan raksasa, ledakan cahaya, gelombang kejut, petir,
// retakan tanah, serpihan jatuh, debu, pasukan terhempas, afterimage. Pakai tekstur sendiri yang udah di-upload
// + partikel (murah, bisa di-batch GPU). Jumlah partikel dikali q.particles, lapisan ekstra cuma di tier tinggi.

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

/** Retakan tanah melingkar dari titik `at` (di permukaan tanah). `glow` = retakan bercahaya yang meredup. */
export function cracks(ctx: VfxCtx, at: Vector3, scale = 1, glow?: Color3) {
	const P = ctx.origin.PointToWorldSpace(at);
	const rng = new Random();
	const n = ctx.q.tier === 0 ? 6 : 12;
	const glows: Part[] = [];
	for (let i = 0; i < n; i++) {
		const ang = (i / n) * math.pi * 2 + rng.NextNumber(-0.2, 0.2);
		let p = P;
		let heading = ang;
		const pieces = rng.NextInteger(2, 3);
		for (let j = 0; j < pieces; j++) {
			const len = rng.NextNumber(2, 4.5) * scale;
			const q = p.add(new Vector3(math.cos(heading) * len, 0, math.sin(heading) * len));
			const w = (0.35 - j * 0.1) * scale;
			const cf = CFrame.lookAt(p.Lerp(q, 0.5), q);
			const crack = host(ctx, cf.add(new Vector3(0, 0.03, 0)));
			crack.Size = new Vector3(w, 0.06, len + w);
			crack.Transparency = 0;
			crack.Color = Color3.fromRGB(58, 52, 50);
			crack.Material = Enum.Material.Slate;
			if (glow && ctx.q.tier >= 1) {
				const g = host(ctx, cf.add(new Vector3(0, 0.07, 0)));
				g.Size = new Vector3(w * 0.4, 0.04, len);
				g.Transparency = 0;
				g.Material = Enum.Material.Neon;
				g.Color = glow;
				glows.push(g);
			}
			p = q;
			heading += rng.NextNumber(-0.5, 0.5);
		}
	}
	if (glows.size() > 0) {
		ctx.tw.add(2.5, (k) => {
			for (const g of glows) g.Transparency = k;
		});
	}
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
