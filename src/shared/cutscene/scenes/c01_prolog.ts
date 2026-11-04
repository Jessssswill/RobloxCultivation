// Cutscene 1 (Prolog, 90 dtk timeline, sekitar 97 dtk asli karena slow-mo):
// Bai Wuji lawan pasukan langit di Pilar Kesembilan, ditahan sosok diam pakai dua jari, pedang patah,
// serpihan jatuh menembus awan ke dunia fana. Set dibikin lokal di langit, jauh dari map, detail ikut tier grafik.
// Dialog Inggris + Mandarin (diucapin TTS). Musik orkestra China tanpa vokal (lihat audio.ts).
// Posisi tusukan vs dua jari dan napak kaki tiap pose udah diukur di Studio (4 Nov); timing kamera tetap cek pas nonton.

import { TEX } from "../audio";
import { block, light, pillar } from "../build";
import { CamKey, CutEvent, CutsceneDef, Tier } from "../types";

const SALT = Color3.fromRGB(236, 232, 224);
const GOLD = Color3.fromRGB(255, 205, 110);
const STONE = Color3.fromRGB(92, 88, 84);
const ROCK = Color3.fromRGB(70, 64, 60);
const VOID = Color3.fromRGB(14, 14, 18);
const QI = Color3.fromRGB(190, 225, 255);
const WHITE = new Color3(1, 1, 1);
const GILT = Color3.fromRGB(214, 172, 92);
const BRONZE = Color3.fromRGB(150, 112, 60);
const LACQUER = Color3.fromRGB(92, 30, 24);
const BANNER = Color3.fromRGB(150, 28, 26);
const BOLT = Color3.fromRGB(225, 232, 255);
/** Tepi retakan / sobekan ruang: putih keunguan, beda sama qi biru Bai Wuji. */
const VOIDRIM = Color3.fromRGB(205, 190, 255);

const v = (x: number, y: number, z: number) => new Vector3(x, y, z);
/** CFrame telapak kaki di (x, y, z) menghadap titik (lx, lz) pada ketinggian yang sama. */
const at = (x: number, y: number, z: number, lx: number, lz: number) => CFrame.lookAt(v(x, y, z), v(lx, y, lz));

// Titik ujung pedang dijepit dua jari Sosok Diam. Diukur di Studio 4 Nov (rig Bai tinggi 1.05 pose thrust di THRUST,
// rig Sosok 1.08 pose twoFinger di at(0, 35, -44)): ujung bilah pas di ujung jari kanan Sosok.
const PINCH = v(-1.47, 39.45, -42.05);
const THRUST = at(-2.9, 35.9, -34.85, -2.9, -100);
/** Retakan utama pas waktu berhenti: sedikit di belakang jari (dari arah kamera close-up) biar tangan + bilah di depannya. */
const PINCH_CRACK = PINCH.add(v(0.66, -0.13, -0.43));

// Serpihan pedang: dilempar lewat pinggir pulau, terus jatuh menembus awan ke desa di bawah (kurva Bezier)
const FALL_T0 = 66;
const FALL_T1 = 82;
const P0 = PINCH;
const P1 = v(10, 110, 320);
const P2 = v(40, -420, 520);
const bezier = (s: number) => P0.mul((1 - s) ** 2).add(P1.mul(2 * (1 - s) * s)).add(P2.mul(s * s));
const shardAt = (t: number) => bezier(math.clamp((t - FALL_T0) / (FALL_T1 - FALL_T0), 0, 1));
const CLOUD_Y = -150;
let cloudT = FALL_T0;
while (cloudT < FALL_T1 && shardAt(cloudT).Y > CLOUD_Y) cloudT += 0.05;

// Mata Langit (天眼): mata raksasa di langit, di kanan Pilar biar gak ketutup. Membuka di awal, melotot pas
// komandan ngomong, menyipit pas sosok diam muncul, menutup pas narasi "the sky only closed its eye".
const EYE = v(250, 420, -600);
const EYE_IRIS = Color3.fromRGB(255, 176, 60);
const EYE_GLARE = Color3.fromRGB(255, 110, 40);

interface EyeRig {
	sclera: Part;
	iris: Part;
	pupil: Part;
	halo: Decal;
	w: number;
	h: number;
	iw: number;
}
let eye: EyeRig | undefined;

function buildEye(root: Folder, tier: Tier) {
	const face = CFrame.lookAt(EYE, v(0, 30, 0));
	const w = tier === 0 ? 260 : 300;
	const h = w * 0.36;
	const iw = h * 0.92;
	const oval = (name: string, size: Vector3, z: number, color: Color3, material: Enum.Material) => {
		const p = block(root, { name, size, cf: face.mul(new CFrame(0, 0, z)), color, material });
		const mesh = new Instance("SpecialMesh");
		mesh.MeshType = Enum.MeshType.Sphere;
		mesh.Parent = p;
		return p;
	};
	const glow = block(root, { name: "EyeHalo", size: v(w * 1.9, h * 2.6, 1), cf: face.mul(new CFrame(0, 0, 4)), transparency: 1 });
	const halo = new Instance("Decal");
	halo.Texture = TEX.glow;
	halo.Color3 = Color3.fromRGB(255, 214, 150);
	halo.Face = Enum.NormalId.Front;
	halo.Transparency = 1;
	halo.Parent = glow;
	eye = {
		sclera: oval("EyeWhite", v(w, h, 6), 0, Color3.fromRGB(250, 238, 210), Enum.Material.Neon),
		iris: oval("EyeIris", v(iw, iw, 6), -3, EYE_IRIS, Enum.Material.Neon),
		pupil: oval("EyePupil", v(iw * 0.16, iw * 0.82, 6), -6, Color3.fromRGB(36, 6, 4), Enum.Material.SmoothPlastic),
		halo,
		w,
		h,
		iw,
	};
}

/** 0 = tertutup, 1 = terbuka, sampai 2 = melotot (pupil menyipit, iris memerah, cahaya lebih terang). */
function setEye(_root: Folder, value: number) {
	if (!eye) return;
	const open = math.clamp(value, 0, 1);
	const glare = math.clamp(value - 1, 0, 1);
	const hidden = open < 0.01 ? 1 : 0;
	const hh = math.max(eye.h * open, 0.1);
	eye.sclera.Size = v(eye.w, hh, 6);
	eye.iris.Size = v(eye.iw, math.min(eye.iw, hh * 0.98), 6);
	eye.pupil.Size = v(eye.iw * (0.16 - 0.07 * glare), math.min(eye.iw * 0.82, hh * 0.9), 6);
	eye.iris.Color = EYE_IRIS.Lerp(EYE_GLARE, glare);
	eye.sclera.Transparency = hidden;
	eye.iris.Transparency = hidden;
	eye.pupil.Transparency = hidden;
	eye.halo.Transparency = 1 - (0.3 + 0.4 * glare) * open;
}

function build(root: Folder, tier: Tier) {
	const rng = new Random(9);
	const kp = (t: number, x: number) => new NumberSequenceKeypoint(t, x);

	// Pulau dataran garam melayang (atas rata, bawah batu bertingkat)
	const island = (h: number, d: number, y: number, color: Color3, mat: Enum.Material) =>
		block(root, {
			size: v(h, d, d),
			cf: new CFrame(0, y, 0).mul(CFrame.Angles(0, 0, math.rad(90))),
			color,
			material: mat,
			shape: Enum.PartType.Cylinder,
		});
	island(6, 400, -3, SALT, Enum.Material.Salt);
	island(40, 370, -26, ROCK, Enum.Material.Slate);
	island(50, 280, -66, ROCK, Enum.Material.Slate);
	island(60, 160, -110, ROCK, Enum.Material.Slate);

	// Lempeng garam beda warna biar permukaan gak polos (tengah dikosongin buat area tarung)
	if (tier >= 1) {
		const plates = tier === 2 ? 40 : 18;
		for (let i = 0; i < plates; i++) {
			const r = rng.NextNumber(16, 175);
			const a = rng.NextNumber(0, math.pi * 2);
			block(root, {
				size: v(rng.NextNumber(8, 22), 0.2, rng.NextNumber(8, 22)),
				cf: new CFrame(math.cos(a) * r, 0.02, math.sin(a) * r).mul(CFrame.Angles(0, rng.NextNumber(0, math.pi), 0)),
				color: SALT.Lerp(Color3.fromRGB(200, 192, 180), rng.NextNumber(0.2, 0.7)),
				material: Enum.Material.Salt,
			});
		}
	}

	// Reruntuhan pilar patah di pinggir pulau (gak di arah kamera pembuka biar gak nutup shot)
	const ruins = tier === 0 ? 5 : 10;
	for (let i = 0; i < ruins; i++) {
		const a = math.rad(100 + (i / ruins) * 290) + rng.NextNumber(-0.1, 0.1);
		const r = rng.NextNumber(150, 185);
		const h = rng.NextNumber(14, 42);
		const d = rng.NextNumber(5, 8);
		const base = new CFrame(math.cos(a) * r, 0, math.sin(a) * r).mul(CFrame.Angles(rng.NextNumber(-0.12, 0.12), 0, rng.NextNumber(-0.12, 0.12)));
		const upright = CFrame.Angles(0, 0, math.rad(90));
		block(root, { size: v(h, d, d), cf: base.mul(new CFrame(0, h / 2 - 1, 0)).mul(upright), color: STONE, material: Enum.Material.Slate, shape: Enum.PartType.Cylinder });
		if (tier >= 1) {
			block(root, { size: v(1.2, d + 0.7, d + 0.7), cf: base.mul(new CFrame(0, h * 0.72, 0)).mul(upright), color: BRONZE, material: Enum.Material.Metal, shape: Enum.PartType.Cylinder });
		}
		if (tier === 2 && i % 2 === 0) {
			const chunk = base.Position.add(v(rng.NextNumber(-9, 9), d / 2 - 0.6, rng.NextNumber(-9, 9)));
			block(root, {
				size: v(rng.NextNumber(5, 9), d, d),
				cf: new CFrame(chunk).mul(CFrame.Angles(0, rng.NextNumber(0, math.pi), math.rad(5))),
				color: STONE,
				material: Enum.Material.Slate,
				shape: Enum.PartType.Cylinder,
			});
		}
	}

	// Batu melayang di sekitar pulau
	if (tier >= 1) {
		const rocks = tier === 2 ? 10 : 5;
		for (let i = 0; i < rocks; i++) {
			const a = math.rad(100 + i * (290 / rocks)) + rng.NextNumber(-0.15, 0.15);
			const r = rng.NextNumber(225, 290);
			const size = rng.NextNumber(8, 22);
			const cf = new CFrame(math.cos(a) * r, rng.NextNumber(-30, 40), math.sin(a) * r).mul(
				CFrame.Angles(rng.NextNumber(-0.3, 0.3), rng.NextNumber(0, 3), rng.NextNumber(-0.3, 0.3)),
			);
			block(root, { size: v(size, size * 0.7, size * 0.9), cf, color: ROCK, material: Enum.Material.Slate });
			block(root, { size: v(size * 0.95, 0.6, size * 0.85), cf: cf.mul(new CFrame(0, size * 0.35, 0)), color: SALT, material: Enum.Material.Salt });
		}
	}

	buildEye(root, tier);

	// Pilar Kesembilan: tiang raksasa dari bawah awan sampai langit, dililit rantai, cincin rune emas
	pillar(root, v(0, 50, -260), 700, 60, STONE, Enum.Material.Slate);
	for (let i = 0; i < 4; i++) {
		block(root, {
			size: v(80, 3, 3),
			cf: new CFrame(0, 40 + i * 60, -228).mul(CFrame.Angles(0, 0, math.rad(i % 2 === 0 ? 14 : -14))),
			color: Color3.fromRGB(60, 58, 56),
			material: Enum.Material.CorrodedMetal,
		});
	}
	if (tier >= 1) {
		for (const y of [70, 150, 240]) pillar(root, v(0, y, -260), 1.4, 64, GOLD, Enum.Material.Neon).Transparency = 0.25;
	}

	// Sinar matahari miring dari langit (god rays), murah: Beam bertekstur glow
	if (tier >= 1) {
		const rays = tier === 2 ? 5 : 2;
		for (let i = 0; i < rays; i++) {
			const holder = block(root, { size: v(1, 1, 1), cf: new CFrame(-160 + i * (320 / rays) + rng.NextNumber(-20, 20), 330, -320), transparency: 1 });
			const top = new Instance("Attachment");
			top.Parent = holder;
			const bottom = new Instance("Attachment");
			bottom.Position = v(60, -390, 220);
			bottom.Parent = holder;
			const beam = new Instance("Beam");
			beam.Attachment0 = top;
			beam.Attachment1 = bottom;
			beam.Texture = TEX.glow;
			beam.TextureMode = Enum.TextureMode.Stretch;
			beam.Width0 = 30;
			beam.Width1 = 70;
			beam.FaceCamera = true;
			beam.LightEmission = 0.7;
			beam.LightInfluence = 0;
			beam.Segments = 2;
			beam.Color = new ColorSequence(Color3.fromRGB(255, 226, 170));
			beam.Transparency = new NumberSequence([kp(0, 0.92), kp(0.5, 0.8), kp(1, 1)]);
			beam.Parent = holder;
		}
	}

	// Butiran qi emas melayang di sekitar area tarung
	if (tier >= 1) {
		const zone = block(root, { size: v(80, 30, 80), cf: new CFrame(0, 12, -10), transparency: 1 });
		const motes = new Instance("ParticleEmitter");
		motes.Shape = Enum.ParticleEmitterShape.Box;
		motes.Texture = TEX.glow;
		motes.Color = new ColorSequence(GOLD, WHITE);
		motes.LightEmission = 1;
		motes.LightInfluence = 0;
		motes.Size = new NumberSequence([kp(0, 0), kp(0.2, 0.35), kp(1, 0)]);
		motes.Transparency = new NumberSequence([kp(0, 1), kp(0.2, 0.2), kp(1, 1)]);
		motes.Lifetime = new NumberRange(5, 9);
		motes.Speed = new NumberRange(0.5, 2);
		motes.SpreadAngle = new Vector2(180, 180);
		motes.Acceleration = v(0.4, 0.8, 0);
		motes.Rate = tier === 2 ? 40 : 15;
		motes.Parent = zone;
	}

	// Pasukan langit bertombak (folder Army, dihempas tebasan raksasa lewat vfx collapse)
	const army = new Instance("Folder");
	army.Name = "Army";
	army.Parent = root;
	const rows = tier === 0 ? 2 : tier === 1 ? 3 : 4;
	for (let row = 0; row < rows; row++) {
		for (let col = -6; col <= 6; col++) {
			const p = v(col * 9 + (row % 2) * 4.5, 40 + row * 14, -130 - row * 20);
			const body = block(army, { size: v(2.2, 4.6, 1.4), cf: new CFrame(p), color: GILT, material: Enum.Material.Metal });
			block(army, { size: v(1.5, 1.5, 1.5), cf: new CFrame(p.add(v(0, 3.2, 0))), color: GOLD, material: Enum.Material.Neon, shape: Enum.PartType.Ball });
			block(army, { size: v(0.25, 11, 0.25), cf: new CFrame(p.add(v(1.6, 1.5, -0.4))), color: LACQUER, material: Enum.Material.Wood });
			if (tier >= 1) {
				block(army, { size: v(3.2, 0.8, 1.8), cf: new CFrame(p.add(v(0, 2.1, 0))), color: GILT, material: Enum.Material.Metal });
				block(army, { size: v(0.3, 1.3, 0.12), cf: new CFrame(p.add(v(1.6, 7.6, -0.4))), color: GOLD, material: Enum.Material.Neon });
				if (col % 4 === 0 && row % 2 === 0) light(body, GOLD, 20, 1);
			}
			// Panji merah-emas di barisan belakang
			if (tier === 2 && row === rows - 1 && col % 3 === 0) {
				block(army, { size: v(0.3, 16, 0.3), cf: new CFrame(p.add(v(-1.6, 6, 0.3))), color: LACQUER, material: Enum.Material.Wood });
				block(army, { size: v(3.4, 6, 0.15), cf: new CFrame(p.add(v(0.2, 10.5, 0.3))), color: BANNER, material: Enum.Material.Fabric });
				block(army, { size: v(3.4, 0.5, 0.2), cf: new CFrame(p.add(v(0.2, 13.6, 0.3))), color: GOLD, material: Enum.Material.Metal });
			}
		}
	}

	// Lapisan awan di bawah pulau, dilewati serpihan. Di grafik ringan lebih sedikit dan gak transparan (overdraw mahal)
	const clouds = tier === 0 ? 18 : tier === 1 ? 32 : 50;
	for (let i = 0; i < clouds; i++) {
		block(root, {
			size: v(rng.NextNumber(70, 150), rng.NextNumber(10, 20), rng.NextNumber(60, 120)),
			cf: new CFrame(rng.NextNumber(-260, 300), rng.NextNumber(CLOUD_Y - 20, CLOUD_Y + 5), rng.NextNumber(120, 760)),
			color: Color3.fromRGB(245, 245, 250),
			transparency: tier === 0 ? 0 : 0.2,
			shape: Enum.PartType.Ball,
		});
	}

	// Desa kecil jauh di bawah (dunia fana): rumah beratap pelana, lampu, pohon
	block(root, { size: v(500, 2, 500), cf: new CFrame(40, -429, 520), color: Color3.fromRGB(40, 56, 34), material: Enum.Material.Grass });
	for (let i = 0; i < 14; i++) {
		const cf = new CFrame(rng.NextNumber(0, 80), -425.5, rng.NextNumber(480, 570)).mul(CFrame.Angles(0, rng.NextNumber(0, math.pi), 0));
		const house = block(root, { size: v(6, 5, 6), cf, color: Color3.fromRGB(70, 52, 40), material: Enum.Material.WoodPlanks });
		if (tier >= 1) {
			const tile = Color3.fromRGB(46, 50, 58);
			block(root, { size: v(7, 0.5, 4.4), cf: cf.mul(new CFrame(0, 3.6, 1.6)).mul(CFrame.Angles(math.rad(35), 0, 0)), color: tile, material: Enum.Material.Slate });
			block(root, { size: v(7, 0.5, 4.4), cf: cf.mul(new CFrame(0, 3.6, -1.6)).mul(CFrame.Angles(math.rad(-35), 0, 0)), color: tile, material: Enum.Material.Slate });
		}
		if (tier >= 1 || i % 4 === 0) light(house, Color3.fromRGB(255, 170, 90), 22, 1.5);
	}
	if (tier === 2) {
		for (let i = 0; i < 10; i++) {
			const at = v(rng.NextNumber(-20, 100), -428, rng.NextNumber(460, 590));
			block(root, { size: v(5, 1, 1), cf: new CFrame(at.add(v(0, 2.5, 0))).mul(CFrame.Angles(0, 0, math.rad(90))), color: Color3.fromRGB(70, 50, 36), material: Enum.Material.Wood, shape: Enum.PartType.Cylinder });
			block(root, { size: v(6, 6, 6), cf: new CFrame(at.add(v(0, 6.5, 0))), color: Color3.fromRGB(46, 74, 40), material: Enum.Material.Grass, shape: Enum.PartType.Ball });
		}
	}
}

const fallCam = (t: number, off: Vector3, fov: number): CamKey => ({ t, pos: shardAt(t).add(off), look: shardAt(t), fov });

const camera: CamKey[] = [
	// S1 0-7: pulau, pilar, pasukan. Crane turun pelan
	{ t: 0, pos: v(90, 70, 170), look: v(0, 100, -260), fov: 50 },
	{ t: 7, pos: v(34, 14, 64), look: v(0, 70, -260), fov: 50, ease: "inOut" },
	// S2 7-12: perkenalan Bai Wuji, low angle muter
	{ t: 7, follow: "bai", pos: v(-5, -1.8, -7), track: "bai", look: v(0, 1.2, 0), fov: 40, dof: 0.35, cut: true },
	{ t: 12, follow: "bai", pos: v(5, -1.5, -7.5), track: "bai", look: v(0, 1.4, 0), fov: 38, dof: 0.35, ease: "inOut" },
	// S3 12-16: komandan langit dari bawah, Mata Langit melotot persis di belakangnya
	{ t: 12, pos: v(-12, 30, -60), track: "commander", look: v(0, 1, 0), fov: 45, dof: 0.12, cut: true },
	{ t: 16, pos: v(-10, 32, -64), track: "commander", look: v(0, 1.2, 0), fov: 40, dof: 0.12, ease: "inOut" },
	// S4 16-19.5: close-up wajah Bai Wuji
	{ t: 16, follow: "bai", pos: v(1.4, 1.6, -3.6), track: "bai", look: v(0, 1.5, 0), fov: 28, dof: 0.6, cut: true },
	{ t: 19.5, follow: "bai", pos: v(0.9, 1.5, -3), track: "bai", look: v(0, 1.5, 0), fov: 26, dof: 0.6, ease: "inOut" },
	// S5 19.5-23.5: pasukan darat menyerbu, kamera di belakang Bai Wuji
	{ t: 19.5, follow: "bai", pos: v(3, 1.2, 9), look: v(0, 3, -40), fov: 60, dof: 0.15, cut: true },
	{ t: 23.5, follow: "bai", pos: v(2.2, 0.6, 6), look: v(0, 3, -8), fov: 74, ease: "in" },
	// S6 23.5-27: tebasan pertama, dari samping
	{ t: 23.5, pos: v(-13, 3.5, -4), look: v(0, 3.5, -4), fov: 55, roll: 6, cut: true },
	{ t: 27, pos: v(-11, 5.5, 3), look: v(0, 3, -4), fov: 58, roll: 0, ease: "out" },
	// S7 27-31: tebasan putar, dari atas serong
	{ t: 27, pos: v(9, 11, 9), look: v(0, 2, 0), fov: 60, cut: true },
	{ t: 31, pos: v(12, 7, -6), look: v(0, 3, 0), fov: 62, ease: "inOut" },
	// S8 31-34: lompat ke langit, kamera di tanah ngikutin
	{ t: 31, pos: v(6, 1.5, 9), track: "bai", look: v(0, 0, 0), fov: 60, dof: 0.1, cut: true },
	{ t: 34, pos: v(8, 3, 14), track: "bai", look: v(0, 0, 0), fov: 72, ease: "out" },
	// S9 34-37: tebasan raksasa ke pasukan, lebar dari belakang
	{ t: 34, follow: "bai", pos: v(-6, 3, 16), look: v(0, 45, -150), fov: 75, cut: true },
	{ t: 37, follow: "bai", pos: v(-9, 5, 20), look: v(0, 42, -150), fov: 80, ease: "out" },
	// S10 37-41: melayang di langit yang kosong
	{ t: 37, follow: "bai", pos: v(7, 0.5, -8), track: "bai", look: v(0, 1, 0), fov: 45, dof: 0.4, cut: true },
	{ t: 41, follow: "bai", pos: v(-7, 1, -8), track: "bai", look: v(0, 1, 0), fov: 45, dof: 0.4, ease: "inOut" },
	// S11 41-46.5: sosok diam muncul, over-shoulder dari belakang Bai Wuji
	{ t: 41, follow: "bai", pos: v(2.4, 2, 5.5), track: "figure", look: v(0, 1.5, 0), fov: 45, dof: 0.5, cut: true },
	{ t: 46.5, follow: "bai", pos: v(1.8, 1.8, 4.5), track: "figure", look: v(0, 1.5, 0), fov: 38, dof: 0.5, ease: "inOut" },
	// S12 46.5-47.6: tusukan, dari samping (Bai di kiri layar, Sosok di kanan)
	{ t: 46.5, pos: v(9, 39.8, -38.5), look: v(-1.5, 39.2, -38.5), fov: 55, cut: true },
	{ t: 47.6, pos: v(7.2, 39.7, -39.8), look: v(-1.47, 39.45, -40.8), fov: 46, ease: "out" },
	// S13 47.6-54: close-up ujung pedang dijepit dua jari, dari sisi luar tangan (jubah Sosok blur di belakang). Hening
	{ t: 47.6, pos: PINCH.add(v(-2.3, 0.45, 1.5)), look: PINCH, fov: 24, dof: 0.8, cut: true },
	{ t: 54, pos: PINCH.add(v(-1.75, 0.35, 1.15)), look: PINCH, fov: 18, dof: 0.8, ease: "inOut" },
	// S14 54-60: pedang patah, terpental, jatuh
	{ t: 54, pos: v(-22, 30, -10), look: v(0, 30, -25), fov: 65, cut: true },
	{ t: 56.5, pos: v(-14, 8, 30), look: v(0, 3, 12), fov: 60, ease: "out" },
	{ t: 60, pos: v(-8, 2.5, 22), look: v(0, 2.5, 12), fov: 48, ease: "inOut" },
	// S15 60-66: berlutut, natap sosok di atas
	{ t: 60, pos: v(-3, 1.2, 19), look: v(0, 30, -40), fov: 55, dof: 0.2, cut: true },
	{ t: 63, pos: v(-2.2, 1, 18), look: v(0, 32, -44), fov: 50, dof: 0.2, ease: "inOut" },
	{ t: 63, follow: "bai", pos: v(0.8, 0.4, -3.2), track: "bai", look: v(0, 0.2, 0), fov: 30, dof: 0.6, cut: true },
	{ t: 66, follow: "bai", pos: v(0.6, 0.3, -2.8), track: "bai", look: v(0, 0.2, 0), fov: 28, dof: 0.6, ease: "inOut" },
	// S16a 66-68.6: Mata Langit menutup ("the sky only closed its eye")
	{ t: 66, pos: v(-4, 2, 26), look: EYE, fov: 32, cut: true },
	{ t: 68.6, pos: v(-3, 2.5, 22), look: EYE, fov: 27, ease: "inOut" },
	// S16b 68.6-82: ngikutin serpihan jatuh menembus awan
	{ ...fallCam(68.6, v(7, 6, -10), 56), cut: true },
	fallCam(72, v(10, 12, -14), 62),
	fallCam(75, v(12, 14, -16), 64),
	fallCam(math.min(cloudT + 0.8, FALL_T1 - 1), v(14, 18, -18), 66),
	{ t: FALL_T1, pos: P2.add(v(30, 40, -40)), look: P2, fov: 60, ease: "out" },
	// S17 82-90: desa di bawah, gelap
	{ t: 90, pos: P2.add(v(40, 60, -60)), look: P2, fov: 55, ease: "inOut" },
];

const BASE_GRADE = { Brightness: 0, Contrast: 0.15, Saturation: 0.05, TintColor: Color3.fromRGB(255, 244, 230) };

const soldiers = ["s1", "s2", "s3", "s4", "s5", "s6"];
const each = (ids: string[], f: (id: string) => CutEvent) => ids.map(f);

const events: CutEvent[] = [
	{ t: 0, kind: "fade", to: 1, dur: 0 },
	{ t: 0.2, kind: "fade", to: 0, dur: 3 },
	// Orkestra China tanpa vokal, dipotong dari detik 22.8 biar klimaksnya jatuh pas tebasan raksasa
	{ t: 0, kind: "music", name: "prologWar", volume: 0.55, fade: 3, from: 22.8 },
	{ t: 0, kind: "sfx", name: "wind", volume: 0.25, loop: true },
	...each(soldiers, (id) => ({ t: 0, kind: "pose", actor: id, pose: "attention", dur: 0 })),
	// Sosok Diam gak pernah napas atau goyang sedikit pun
	{ t: 0, kind: "still", actor: "figure", on: true },
	{ t: 1.2, kind: "prop", name: "eye", to: 1, dur: 3.5, ease: "inOut" },
	{ t: 1.8, kind: "sub", text: "Ten thousand years ago. The Ninth Pillar.", zh: "一万年前，第九天柱。", voice: "narrator", dur: 4 },
	{ t: 3.2, kind: "vfx", name: "lightning", at: v(100, 450, -300), to: v(31, 200, -262), scale: 2.5, color: BOLT },
	{ t: 3.3, kind: "sfx", name: "thunder", volume: 0.35 },

	// Perkenalan
	{ t: 7, kind: "pose", actor: "bai", pose: "guard", dur: 1.5, ease: "inOut" },
	{ t: 7.6, kind: "card", name: "BAI WUJI", cn: "白无极", epithet: "The Sword That Defied Heaven", dur: 4 },
	{ t: 7.6, kind: "sfx", name: "gong", volume: 0.45 },

	// Komandan langit. Petir nyambar Pilar di belakangnya
	{ t: 11.7, kind: "vfx", name: "lightning", at: v(-80, 300, -250), to: v(-31, 120, -255), scale: 1.6, color: BOLT },
	{ t: 11.75, kind: "sfx", name: "thunder", volume: 0.5 },
	{ t: 11.8, kind: "shake", mag: 0.2, dur: 0.5 },
	{ t: 12, kind: "prop", name: "eye", to: 1.7, dur: 0.4, ease: "out" },
	{ t: 16.2, kind: "prop", name: "eye", to: 1, dur: 1.5, ease: "inOut" },
	{ t: 12.3, kind: "pose", actor: "commander", pose: "pointForward", dur: 1, ease: "inOut" },
	{
		t: 12.3,
		kind: "sub",
		who: "Heavenly Commander",
		text: "Bai Wuji. Kneel, and Heaven may yet forgive you.",
		zh: "白无极，跪下。天道或可宽恕你。",
		voice: "commander",
		dur: 3.5,
	},
	{ t: 13.6, kind: "vfx", name: "lightning", at: v(80, 310, -250), to: v(31, 140, -258), scale: 1.4, color: BOLT },
	{ t: 16.5, kind: "sub", who: "Bai Wuji", text: "Heaven has never once asked for mine.", zh: "天道……何曾求过我的宽恕？", voice: "bai", dur: 3 },

	// Serbuan pertama: prajurit lari beneran (siklus langkah dari kecepatan), tombak maju, terus dihempas satu tebasan
	{ t: 19.5, kind: "move", actor: "s1", to: at(-3.5, 0, -5.5, 0, 0), dur: 3.8, ease: "in", ghost: true },
	{ t: 19.5, kind: "move", actor: "s2", to: at(0, 0, -6.5, 0, 0), dur: 3.9, ease: "in", ghost: true },
	{ t: 19.5, kind: "move", actor: "s3", to: at(3.5, 0, -5.5, 0, 0), dur: 3.7, ease: "in", ghost: true },
	...each(["s1", "s2", "s3"], (id) => ({ t: 19.5, kind: "pose", actor: id, pose: "charge", dur: 0.4, ease: "out" })),
	{ t: 19.6, kind: "sfx", name: "whoosh", volume: 0.5, pitch: 0.8 },
	{ t: 20.5, kind: "lines", dur: 3 },
	...each(["s1", "s2", "s3"], (id) => ({ t: 22.5, kind: "pose", actor: id, pose: "thrust", dur: 0.5, ease: "out" })),
	{ t: 22.6, kind: "pose", actor: "bai", pose: "drawStance", dur: 0.6, ease: "inOut" },
	{ t: 23.2, kind: "aura", actor: "bai", on: true },
	{ t: 23.3, kind: "glint", actor: "bai" },
	{ t: 23.45, kind: "pose", actor: "bai", pose: "slashWindup", dur: 0.22, ease: "out" },
	{ t: 23.75, kind: "pose", actor: "bai", pose: "slashFollow", dur: 0.12, ease: "back" },
	{ t: 23.75, kind: "move", actor: "bai", to: at(0, 0, -1.6, 0, -100), dur: 0.14, ease: "expoOut", ghost: true },
	{ t: 23.75, kind: "sfx", name: "slash", volume: 0.9 },
	{ t: 23.75, kind: "vfx", name: "slash", at: v(-7, 4.5, -5), to: v(7, 2.5, -6), color: QI, style: "ink" },
	// Ruang ikut kesobek di jalur tebasan
	{ t: 23.78, kind: "vfx", name: "rift", at: v(-7, 4.5, -5.4), to: v(7, 2.5, -6.4), color: VOIDRIM, scale: 0.6, life: 0.7 },
	{ t: 23.8, kind: "impact", strength: 1 },
	{ t: 23.8, kind: "vfx", name: "burst", at: v(-3.5, 3, -5.5), color: GOLD },
	{ t: 23.82, kind: "vfx", name: "burst", at: v(0, 3, -6.5), color: GOLD },
	{ t: 23.84, kind: "vfx", name: "burst", at: v(3.5, 3, -5.5), color: GOLD },
	{ t: 23.82, kind: "knock", actor: "s1", dir: v(-0.6, 0.15, -1), power: 38, fade: 0.8 },
	{ t: 23.84, kind: "knock", actor: "s2", dir: v(0, 0.2, -1), power: 42, fade: 0.8 },
	{ t: 23.86, kind: "knock", actor: "s3", dir: v(0.6, 0.15, -1), power: 38, fade: 0.8 },
	{ t: 23.9, kind: "speed", scale: 0.35 },
	{ t: 24, kind: "vfx", name: "ring", at: v(0, 0.3, 0), scale: 36, color: QI },
	{ t: 24.6, kind: "speed", scale: 1 },
	{ t: 25, kind: "pose", actor: "bai", pose: "guard", dur: 1, ease: "inOut" },
	{ t: 25.2, kind: "move", actor: "bai", to: at(0, 0, 0, 0, -100), dur: 1, ease: "inOut" },
	{ t: 25.3, kind: "aura", actor: "bai", on: false },

	// Serbuan kedua dari tiga arah + tebasan putar (badan muter penuh, bilah datar nyapu lingkaran)
	{ t: 26.8, kind: "sub", who: "Heavenly Commander", text: "All of you. Bring him down!", zh: "众将听令，拿下他！", voice: "commander", dur: 2.5 },
	{ t: 27, kind: "move", actor: "s4", to: at(-4, 0, -1, 0, 0), dur: 1.9, ease: "in", ghost: true },
	{ t: 27, kind: "move", actor: "s5", to: at(4, 0, -1, 0, 0), dur: 1.9, ease: "in", ghost: true },
	{ t: 27, kind: "move", actor: "s6", to: at(0, 0, 4.5, 0, 0), dur: 1.9, ease: "in", ghost: true },
	...each(["s4", "s5", "s6"], (id) => ({ t: 27, kind: "pose", actor: id, pose: "charge", dur: 0.4, ease: "out" })),
	...each(["s4", "s5", "s6"], (id) => ({ t: 28.3, kind: "pose", actor: id, pose: "thrust", dur: 0.4, ease: "out" })),
	{ t: 28.5, kind: "pose", actor: "bai", pose: "spinReady", dur: 0.3, ease: "out" },
	{ t: 28.7, kind: "aura", actor: "bai", on: true },
	{ t: 29.05, kind: "pose", actor: "bai", pose: "spinSlash", dur: 0.1, ease: "back" },
	{ t: 29.05, kind: "move", actor: "bai", to: at(0, 0, 0, 0, -100), dur: 0.34, ease: "out", ghost: true, spin: -360 },
	{ t: 29.1, kind: "sfx", name: "slash", volume: 0.9, pitch: 1.1 },
	{ t: 29.1, kind: "sfx", name: "whoosh", volume: 0.5, pitch: 1.2 },
	{ t: 29.1, kind: "vfx", name: "ring", at: v(0, 3, 0), scale: 22, color: QI },
	{ t: 29.15, kind: "vfx", name: "slash", at: v(-5, 3.5, 3), to: v(-5, 2.5, -4), color: QI, style: "ink" },
	{ t: 29.2, kind: "vfx", name: "slash", at: v(5, 3, -4), to: v(4, 3.5, 4), color: QI, style: "ink" },
	{ t: 29.25, kind: "impact", strength: 1.2 },
	{ t: 29.25, kind: "vfx", name: "burst", at: v(-4, 3, -1), color: GOLD },
	{ t: 29.27, kind: "vfx", name: "burst", at: v(4, 3, -1), color: GOLD },
	{ t: 29.29, kind: "vfx", name: "burst", at: v(0, 3, 4.5), color: GOLD },
	{ t: 29.26, kind: "knock", actor: "s4", dir: v(-1, 0.2, 0), power: 40, fade: 0.8 },
	{ t: 29.27, kind: "knock", actor: "s5", dir: v(1, 0.2, 0), power: 40, fade: 0.8 },
	{ t: 29.28, kind: "knock", actor: "s6", dir: v(0, 0.2, 1), power: 40, fade: 0.8 },
	{ t: 29.3, kind: "speed", scale: 0.3 },
	{ t: 29.9, kind: "speed", scale: 1 },
	{ t: 30, kind: "pose", actor: "bai", pose: "guard", dur: 0.8, ease: "inOut" },
	{ t: 30.4, kind: "aura", actor: "bai", on: false },

	// Lompat ke langit sambil muter, sayap cahaya mekar, tebasan raksasa nyobek langit dan menghempas seluruh pasukan
	{ t: 31.2, kind: "aura", actor: "bai", on: true },
	{ t: 31.2, kind: "pose", actor: "bai", pose: "crouch", dur: 0.35, ease: "out" },
	{ t: 31.6, kind: "sfx", name: "whoosh", volume: 0.8 },
	{ t: 31.6, kind: "sfx", name: "thud", volume: 0.6 },
	{ t: 31.6, kind: "pose", actor: "bai", pose: "leapTuck", dur: 0.25, ease: "out" },
	{ t: 31.6, kind: "move", actor: "bai", to: at(0, 35, -30, 0, -200), dur: 1.6, ease: "expoOut", ghost: true, spin: -360 },
	{ t: 31.6, kind: "vfx", name: "debris", at: v(0, 0, 0) },
	{ t: 31.6, kind: "vfx", name: "cracks", at: v(0, 0, 0), scale: 1.2, color: QI },
	{ t: 31.6, kind: "vfx", name: "ring", at: v(0, 0.3, 0), scale: 30, color: SALT },
	{ t: 31.65, kind: "shake", mag: 0.8, dur: 0.5 },
	{ t: 32.6, kind: "pose", actor: "bai", pose: "hover", dur: 0.8, ease: "inOut" },
	{ t: 33.3, kind: "pose", actor: "bai", pose: "overhead", dur: 0.45, ease: "out" },
	{ t: 33.3, kind: "wings", actor: "bai", on: true },
	{ t: 33.35, kind: "glint", actor: "bai" },
	{ t: 34.3, kind: "pose", actor: "bai", pose: "downSlash", dur: 0.14, ease: "back" },
	{ t: 34.3, kind: "sfx", name: "bigSlash", volume: 1 },
	{ t: 34.3, kind: "vfx", name: "wave", at: v(0, 36.5, -33), to: v(0, 48, -150), scale: 1.2, dur: 0.5, color: QI, style: "ink" },
	{ t: 34.8, kind: "vfx", name: "slash", at: v(-90, 75, -150), to: v(90, 35, -150), dur: 1.2, color: QI, style: "ink" },
	{ t: 34.82, kind: "vfx", name: "rift", at: v(-90, 75, -150), to: v(90, 35, -150), color: VOIDRIM, life: 2.2 },
	{ t: 34.8, kind: "impact", strength: 1.6 },
	{ t: 34.8, kind: "sfx", name: "boom", volume: 0.8 },
	{ t: 34.8, kind: "vfx", name: "collapse", at: v(0, 40, -60), target: "Army", dur: 2.6 },
	{ t: 34.85, kind: "vfx", name: "burst", at: v(0, 58, -100), scale: 2, color: GOLD },
	{ t: 34.85, kind: "knock", actor: "commander", dir: v(0, 0.3, -1), power: 70 },
	{ t: 34.9, kind: "vfx", name: "burst", at: v(-30, 55, -150), scale: 4, color: GOLD },
	{ t: 35, kind: "vfx", name: "burst", at: v(10, 48, -165), scale: 4, color: GOLD },
	{ t: 35.1, kind: "vfx", name: "burst", at: v(40, 42, -150), scale: 4, color: GOLD },
	{ t: 34.9, kind: "shake", mag: 1.4, dur: 1.2 },
	{ t: 35.1, kind: "speed", scale: 0.4 },
	{ t: 35.6, kind: "wings", actor: "bai", on: false },
	{ t: 36, kind: "speed", scale: 1 },
	{ t: 36.5, kind: "pose", actor: "bai", pose: "hover", dur: 1.4, ease: "inOut" },
	{ t: 37, kind: "aura", actor: "bai", on: false },
	{ t: 37, kind: "hide", actor: "commander" },

	// Langit kosong, musik hilang. Ruang retak, Sosok Diam keluar dari celahnya, dunia jadi dingin
	{ t: 38.8, kind: "music", name: "none", fade: 1.2 },
	{ t: 40.8, kind: "music", name: "prologFigure", volume: 0.32, fade: 1.5 },
	{ t: 40.8, kind: "prop", name: "eye", to: 0.55, dur: 1.5, ease: "inOut" },
	{ t: 41, kind: "show", actor: "figure" },
	{ t: 41, kind: "pose", actor: "figure", pose: "handsBehind", dur: 0 },
	// Habis pindah shot (41), biar bidang retakan menghadap kamera yang baru
	{ t: 41.05, kind: "vfx", name: "spaceCrack", at: v(0, 38.8, -44.6), color: VOIDRIM, life: 1.2 },
	{ t: 41.05, kind: "vfx", name: "burst", at: v(0, 38.5, -44), scale: 2, color: WHITE },
	{ t: 41.05, kind: "vfx", name: "ring", at: v(0, 38.5, -44), normal: v(0, 0, 1), scale: 18, color: WHITE },
	{ t: 41.05, kind: "sfx", name: "gong", volume: 0.35, pitch: 0.6 },
	{ t: 41.05, kind: "grade", to: { Saturation: -0.2, TintColor: Color3.fromRGB(232, 238, 255) }, dur: 2 },
	{ t: 42.6, kind: "sub", who: "Bai Wuji", text: "...You.", zh: "……是你。", voice: "bai", dur: 2 },
	{ t: 46.2, kind: "aura", actor: "bai", on: true },
	{ t: 46.25, kind: "glint", actor: "bai" },
	{ t: 46.5, kind: "pose", actor: "bai", pose: "thrust", dur: 0.2, ease: "back" },
	{ t: 46.5, kind: "move", actor: "bai", to: THRUST, dur: 0.35, ease: "expoOut", ghost: true },
	{ t: 46.5, kind: "sfx", name: "whoosh" },
	{ t: 46.75, kind: "pose", actor: "figure", pose: "twoFinger", dur: 0.15, ease: "out" },
	{ t: 46.95, kind: "still", actor: "bai", on: true },
	{ t: 47, kind: "impact", strength: 1.4 },
	{ t: 47, kind: "sfx", name: "clash", volume: 1 },
	{ t: 47, kind: "vfx", name: "ring", at: PINCH, normal: v(0, 0, 1), scale: 26, color: WHITE },
	// Ruang retak di titik benturan lalu pecah kayak kaca, selesai sebelum pindah ke close-up (47.6)
	{ t: 47, kind: "vfx", name: "spaceCrack", at: PINCH, scale: 0.7, color: VOIDRIM, stages: [0.12], shatter: 0.35 },
	{ t: 47.05, kind: "speed", scale: 0.12 },
	{ t: 47.3, kind: "music", name: "none", fade: 0.8 },
	{ t: 47.6, kind: "speed", scale: 1 },
	// Waktu seakan berhenti: warna hampir hilang, ruang di belakang jari retak makin lebar tiap bunyi retak
	{ t: 47.65, kind: "grade", to: { Saturation: -0.9, Contrast: 0.35 }, dur: 0.25 },
	{ t: 47.65, kind: "freeze", on: true },
	{ t: 47.65, kind: "vfx", name: "spaceCrack", at: PINCH_CRACK, scale: 0.36, color: VOIDRIM, stages: [1.85, 3.85], life: 6.35 },
	{ t: 49.5, kind: "sfx", name: "crack", volume: 0.6 },
	{ t: 49.5, kind: "vfx", name: "burst", at: PINCH, scale: 0.3, color: QI },
	{ t: 51.5, kind: "sfx", name: "crack", volume: 0.8 },
	{ t: 51.5, kind: "vfx", name: "burst", at: PINCH, scale: 0.4, color: QI },
	{ t: 52.8, kind: "shake", mag: 0.25, dur: 1.2 },

	// Pedang pecah berkeping, ruang di sekitarnya ikut pecah kayak kaca. Satu serpihan tetap terjepit di jari
	{ t: 54, kind: "fade", to: 0.25, dur: 0.05, color: WHITE },
	{ t: 54.08, kind: "fade", to: 0, dur: 0.7, color: WHITE },
	{ t: 54, kind: "grade", to: { Saturation: -0.1, Contrast: 0.15, TintColor: Color3.fromRGB(240, 242, 255) }, dur: 0.5 },
	{ t: 54, kind: "still", actor: "bai", on: false },
	{ t: 54, kind: "break", actor: "bai" },
	{ t: 54, kind: "vfx", name: "shard", at: PINCH, color: QI, life: FALL_T0 - 54 },
	{ t: 54, kind: "freeze", on: false },
	{ t: 54, kind: "aura", actor: "bai", on: false },
	{ t: 54, kind: "sfx", name: "shatter", volume: 1 },
	{ t: 54, kind: "sfx", name: "boom", volume: 0.7, pitch: 0.8 },
	{ t: 54, kind: "impact", strength: 2 },
	{ t: 54, kind: "pose", actor: "bai", pose: "fallBack", dur: 0.15, ease: "out" },
	{ t: 54, kind: "move", actor: "bai", to: at(0, 20, 2, 0, -100), dur: 1.1, ease: "expoOut", ghost: true, flip: 360 },
	{ t: 54.02, kind: "vfx", name: "spaceCrack", at: PINCH, scale: 1.4, color: VOIDRIM, shatter: 0.12 },
	{ t: 54.05, kind: "vfx", name: "burst", at: PINCH, scale: 2, color: QI },
	{ t: 54.2, kind: "speed", scale: 0.4 },
	{ t: 54.8, kind: "speed", scale: 1 },
	{ t: 55.2, kind: "move", actor: "bai", to: at(0, 0, 12, 0, -100), dur: 1.3, ease: "in" },
	{ t: 56.5, kind: "vfx", name: "debris", at: v(0, 0, 12) },
	{ t: 56.5, kind: "vfx", name: "cracks", at: v(0, 0, 12), scale: 1.3, color: QI },
	{ t: 56.5, kind: "vfx", name: "ring", at: v(0, 0.3, 12), scale: 30, color: SALT },
	{ t: 56.5, kind: "shake", mag: 1, dur: 0.6 },
	{ t: 56.5, kind: "sfx", name: "thud", volume: 0.8 },
	{ t: 56.5, kind: "pose", actor: "bai", pose: "landing", dur: 0.1, ease: "out" },
	{ t: 56.8, kind: "music", name: "prologEnd", volume: 0.45, fade: 2.5, from: 62.2 },
	{ t: 57.4, kind: "pose", actor: "bai", pose: "kneel", dur: 1.2, ease: "inOut" },
	{ t: 60.5, kind: "pose", actor: "bai", pose: "kneelLookUp", dur: 1.5, ease: "inOut" },
	{ t: 63.3, kind: "sub", who: "Bai Wuji", text: "Who... are you?", zh: "你……究竟是谁？", voice: "bai", dur: 2.4 },
	{ t: 65.4, kind: "vfx", name: "burst", at: v(0, 38, -44), scale: 1.5, color: WHITE },
	{ t: 65.5, kind: "hide", actor: "figure" },

	// Serpihan jatuh ke dunia fana
	{ t: FALL_T0, kind: "vfx", name: "fall", at: P0, via: P1, to: P2, dur: FALL_T1 - FALL_T0, color: QI },
	{ t: FALL_T0, kind: "grade", to: BASE_GRADE, dur: 3 },
	{ t: 66.4, kind: "prop", name: "eye", to: 0, dur: 2, ease: "in" },
	{ t: 66.2, kind: "sub", text: "No one answered. The sky only closed its eye.", zh: "无人回答。苍天，只是闭上了眼。", voice: "narrator", dur: 3.5 },
	{ t: 70, kind: "sub", text: "One shard of his sword fell through the clouds...", zh: "他的剑，碎了一片，坠穿云海……", voice: "narrator", dur: 3.5 },
	{ t: cloudT, kind: "vfx", name: "ring", at: shardAt(cloudT), scale: 70, color: WHITE },
	{ t: cloudT, kind: "shake", mag: 0.4, dur: 0.5 },
	{ t: cloudT, kind: "sfx", name: "whoosh" },
	{ t: 74.5, kind: "sub", text: "...into the world of mortals, and waited.", zh: "落入凡尘，静静等待。", voice: "narrator", dur: 4 },
	{ t: FALL_T1, kind: "vfx", name: "burst", at: P2, scale: 3, color: QI },
	{ t: FALL_T1, kind: "vfx", name: "ring", at: P2.add(v(0, 0.5, 0)), scale: 25, color: QI },
	{ t: 83, kind: "fade", to: 1, dur: 2.5 },
	{ t: 85.5, kind: "title", text: "DUST THAT DEFIES THE SKY", cn: "逆天之尘", sub: "Prologue  ·  序章", dur: 4.5 },
	{ t: 85.5, kind: "sfx", name: "gong", volume: 0.6 },
	{ t: 86, kind: "voice", zh: "序章。逆天之尘。", voice: "narrator" },
	{ t: 88.6, kind: "music", name: "none", fade: 1.4 },
];

export const C01_PROLOG: CutsceneDef = {
	id: "c01_prolog",
	title: "The Ninth Pillar",
	chapter: "Prologue",
	length: 90,
	anchor: "Prolog",
	origin: new CFrame(0, 1200, -4000),
	look: {
		lighting: {
			ClockTime: 17.4,
			Brightness: 2.2,
			ExposureCompensation: 0.1,
			Ambient: Color3.fromRGB(110, 100, 95),
			OutdoorAmbient: Color3.fromRGB(150, 140, 130),
			FogColor: Color3.fromRGB(235, 222, 200),
			FogEnd: 3000,
		},
		atmosphere: { Density: 0.32, Haze: 1.6, Glare: 0.4, Offset: 0.1, Color: Color3.fromRGB(240, 220, 190), Decay: Color3.fromRGB(180, 140, 110) },
		grade: BASE_GRADE,
		bloom: { Intensity: 0.6, Size: 28, Threshold: 1.6 },
		handheld: 0.25,
	},
	build,
	props: { eye: { init: 0, set: setEye } },
	actors: [
		// Kostum dari katalog dirakit server (server/cutscene/service.ts). Warna/material = cadangan kalau rig belum siap
		{
			id: "bai",
			look: "template",
			template: "BaiWuji",
			color: Color3.fromRGB(235, 235, 240),
			// Spirit Sword yang udah ada di place (mesh + PBR + rumbai), cadangan pedang part kalau gak ketemu
			sword: "BaiSword",
			swordScale: 0.8,
			weapon: "jian",
			ghostColor: QI,
			aura: QI,
			outline: { color: QI, alpha: 0.65 },
			start: at(0, 0, 0, 0, -100),
		},
		{ id: "commander", look: "template", template: "Commander", color: GOLD, material: Enum.Material.Neon, outline: { color: GOLD, alpha: 0.5 }, start: at(0, 55, -100, 0, 0) },
		...[
			["s1", at(-10, 0, -60, 0, 0)],
			["s2", at(0, 0, -64, 0, 0)],
			["s3", at(10, 0, -60, 0, 0)],
			["s4", at(-30, 0, -10, 0, 0)],
			["s5", at(30, 0, -10, 0, 0)],
			["s6", at(0, 0, 40, 0, 0)],
		].map(([id, start]) => ({
			id: id as string,
			look: "template" as const,
			template: "HeavenSoldier",
			color: GOLD,
			material: Enum.Material.Neon,
			weapon: "spear" as const,
			ghostColor: GOLD,
			outline: { color: GOLD, alpha: 0.7 },
			start: start as CFrame,
		})),
		{
			id: "figure",
			look: "template",
			template: "Figure",
			color: VOID,
			material: Enum.Material.SmoothPlastic,
			outline: { color: WHITE, alpha: 0.15, key: true },
			start: at(0, 35, -44, 0, 0),
			hidden: true,
		},
	],
	camera,
	events,
};
