// Cutscene 1 (Prolog, 90 dtk timeline, sekitar 97 dtk asli karena slow-mo):
// Bai Wuji lawan pasukan langit di Pilar Kesembilan, ditahan sosok diam pakai dua jari, pedang patah,
// serpihan jatuh menembus awan ke dunia fana. Versi greybox: set dibikin lokal di langit, jauh dari map.
// Timing, pose, dan posisi kamera masih tebakan di atas kertas, wajib dicek dan disetel di Studio.

import { CamKey, CutEvent, CutsceneDef } from "../types";
import { block, light, pillar } from "../build";

const SALT = Color3.fromRGB(236, 232, 224);
const GOLD = Color3.fromRGB(255, 205, 110);
const STONE = Color3.fromRGB(92, 88, 84);
const ROCK = Color3.fromRGB(70, 64, 60);
const VOID = Color3.fromRGB(14, 14, 18);
const QI = Color3.fromRGB(190, 225, 255);
const WHITE = new Color3(1, 1, 1);

const v = (x: number, y: number, z: number) => new Vector3(x, y, z);
/** CFrame telapak kaki di (x, y, z) menghadap titik (lx, lz) pada ketinggian yang sama. */
const at = (x: number, y: number, z: number, lx: number, lz: number) => CFrame.lookAt(v(x, y, z), v(lx, y, lz));
/** Hero menghadap -Z sambil diputar (derajat, searah jarum jam dilihat dari atas). */
const spin = (deg: number) => CFrame.Angles(0, math.rad(-deg), 0);

// Serpihan pedang: dilempar lewat pinggir pulau, terus jatuh menembus awan ke desa di bawah (kurva Bezier)
const FALL_T0 = 66;
const FALL_T1 = 82;
const P0 = v(0, 38.5, -41.5);
const P1 = v(10, 110, 320);
const P2 = v(40, -420, 520);
const bezier = (s: number) => P0.mul((1 - s) ** 2).add(P1.mul(2 * (1 - s) * s)).add(P2.mul(s * s));
const shardAt = (t: number) => bezier(math.clamp((t - FALL_T0) / (FALL_T1 - FALL_T0), 0, 1));
const CLOUD_Y = -150;
let cloudT = FALL_T0;
while (cloudT < FALL_T1 && shardAt(cloudT).Y > CLOUD_Y) cloudT += 0.05;

function build(root: Folder, low: boolean) {
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

	// Pilar Kesembilan: tiang raksasa dari bawah awan sampai langit, dililit rantai
	pillar(root, v(0, 50, -260), 700, 60, STONE, Enum.Material.Slate);
	for (let i = 0; i < 4; i++) {
		block(root, {
			size: v(80, 3, 3),
			cf: new CFrame(0, 40 + i * 60, -228).mul(CFrame.Angles(0, 0, math.rad(i % 2 === 0 ? 14 : -14))),
			color: Color3.fromRGB(60, 58, 56),
			material: Enum.Material.CorrodedMetal,
		});
	}

	// Pasukan langit (folder Army, dihempas tebasan raksasa lewat vfx collapse)
	const army = new Instance("Folder");
	army.Name = "Army";
	army.Parent = root;
	const rows = low ? 2 : 4;
	for (let row = 0; row < rows; row++) {
		for (let col = -6; col <= 6; col++) {
			const p = v(col * 9 + (row % 2) * 4.5, 40 + row * 14, -130 - row * 20);
			const body = block(army, { size: v(2.2, 5.5, 1.4), cf: new CFrame(p), color: GOLD, material: Enum.Material.Neon });
			block(army, {
				size: v(1.6, 1.6, 1.6),
				cf: new CFrame(p.add(v(0, 3.8, 0))),
				color: GOLD,
				material: Enum.Material.Neon,
				shape: Enum.PartType.Ball,
			});
			if (!low && col % 4 === 0 && row % 2 === 0) light(body, GOLD, 20, 1);
		}
	}

	// Lapisan awan di bawah pulau, dilewati serpihan. Di HP lebih sedikit dan gak transparan (overdraw mahal)
	const rng = new Random(9);
	const clouds = low ? 18 : 50;
	for (let i = 0; i < clouds; i++) {
		block(root, {
			size: v(rng.NextNumber(70, 150), rng.NextNumber(10, 20), rng.NextNumber(60, 120)),
			cf: new CFrame(rng.NextNumber(-260, 300), rng.NextNumber(CLOUD_Y - 20, CLOUD_Y + 5), rng.NextNumber(120, 760)),
			color: Color3.fromRGB(245, 245, 250),
			transparency: low ? 0 : 0.2,
			shape: Enum.PartType.Ball,
		});
	}

	// Desa kecil jauh di bawah (dunia fana), cuma rumah dan lampu
	block(root, { size: v(500, 2, 500), cf: new CFrame(40, -429, 520), color: Color3.fromRGB(40, 56, 34), material: Enum.Material.Grass });
	for (let i = 0; i < 14; i++) {
		const house = block(root, {
			size: v(6, 5, 6),
			cf: new CFrame(rng.NextNumber(0, 80), -425.5, rng.NextNumber(480, 570)),
			color: Color3.fromRGB(70, 52, 40),
		});
		if (!low || i % 4 === 0) light(house, Color3.fromRGB(255, 170, 90), 22, 1.5);
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
	// S3 12-16: komandan langit dari bawah
	{ t: 12, pos: v(8, 38, -78), track: "commander", look: v(0, 1, 0), fov: 45, dof: 0.3, cut: true },
	{ t: 16, pos: v(5, 40, -82), track: "commander", look: v(0, 1.2, 0), fov: 40, dof: 0.3, ease: "inOut" },
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
	// S12 46.5-47.6: tusukan, dari samping
	{ t: 46.5, pos: v(10, 38, -40), look: v(0, 38, -40), fov: 55, cut: true },
	{ t: 47.6, pos: v(8, 38.5, -41), look: v(0, 38.5, -41.5), fov: 45, ease: "out" },
	// S13 47.6-54: close-up ujung pedang dijepit dua jari. Hening
	{ t: 47.6, follow: "figure", pos: v(2.4, 1.6, 2.2), track: "figure", look: v(0, 1.3, 1.8), fov: 24, dof: 0.8, cut: true },
	{ t: 54, follow: "figure", pos: v(1.9, 1.45, 2.4), track: "figure", look: v(0, 1.3, 1.8), fov: 18, dof: 0.8, ease: "inOut" },
	// S14 54-60: pedang patah, terpental, jatuh
	{ t: 54, pos: v(-22, 30, -10), look: v(0, 30, -25), fov: 65, cut: true },
	{ t: 56.5, pos: v(-14, 8, 30), look: v(0, 3, 12), fov: 60, ease: "out" },
	{ t: 60, pos: v(-8, 2.5, 22), look: v(0, 2.5, 12), fov: 48, ease: "inOut" },
	// S15 60-66: berlutut, natap sosok di atas
	{ t: 60, pos: v(-3, 1.2, 19), look: v(0, 30, -40), fov: 55, dof: 0.2, cut: true },
	{ t: 63, pos: v(-2.2, 1, 18), look: v(0, 32, -44), fov: 50, dof: 0.2, ease: "inOut" },
	{ t: 63, follow: "bai", pos: v(0.8, 0.4, -3.2), track: "bai", look: v(0, 0.2, 0), fov: 30, dof: 0.6, cut: true },
	{ t: 66, follow: "bai", pos: v(0.6, 0.3, -2.8), track: "bai", look: v(0, 0.2, 0), fov: 28, dof: 0.6, ease: "inOut" },
	// S16 66-82: ngikutin serpihan jatuh menembus awan
	{ ...fallCam(FALL_T0, v(6, 4, -8), 55), cut: true },
	fallCam(69, v(8, 8, -12), 58),
	fallCam(72, v(10, 12, -14), 62),
	fallCam(75, v(12, 14, -16), 64),
	fallCam(math.min(cloudT + 0.8, FALL_T1 - 1), v(14, 18, -18), 66),
	{ t: FALL_T1, pos: P2.add(v(30, 40, -40)), look: P2, fov: 60, ease: "out" },
	// S17 82-90: desa di bawah, gelap
	{ t: 90, pos: P2.add(v(40, 60, -60)), look: P2, fov: 55, ease: "inOut" },
];

const events: CutEvent[] = [
	{ t: 0, kind: "fade", to: 1, dur: 0 },
	{ t: 0.2, kind: "fade", to: 0, dur: 3 },
	{ t: 0, kind: "music", name: "prologWar", volume: 0.6, fade: 3 },
	{ t: 0, kind: "sfx", name: "wind" },
	{ t: 1.8, kind: "sub", text: "Ten thousand years ago. The Ninth Pillar.", dur: 4 },

	// Perkenalan
	{ t: 7, kind: "pose", actor: "bai", pose: "guard", dur: 1.5, ease: "inOut" },
	{ t: 7.6, kind: "card", name: "BAI WUJI", cn: "白无极", epithet: "The Sword That Defied Heaven", dur: 4 },
	{ t: 12.3, kind: "pose", actor: "commander", pose: "pointForward", dur: 1, ease: "inOut" },
	{ t: 12.3, kind: "sub", who: "Heavenly Commander", text: "Bai Wuji. Kneel, and Heaven may yet forgive you.", dur: 3.5 },
	{ t: 16.4, kind: "sub", who: "Bai Wuji", text: "Heaven has never once asked for mine.", dur: 3 },

	// Serbuan pertama + tebasan
	{ t: 19.5, kind: "move", actor: "s1", to: at(-3.5, 0, -5.5, 0, 0), dur: 3.8, ease: "in", ghost: true },
	{ t: 19.5, kind: "move", actor: "s2", to: at(0, 0, -6.5, 0, 0), dur: 3.9, ease: "in", ghost: true },
	{ t: 19.5, kind: "move", actor: "s3", to: at(3.5, 0, -5.5, 0, 0), dur: 3.7, ease: "in", ghost: true },
	{ t: 20.5, kind: "pose", actor: "s1", pose: "thrust", dur: 1.5 },
	{ t: 20.5, kind: "pose", actor: "s2", pose: "thrust", dur: 1.5 },
	{ t: 20.5, kind: "pose", actor: "s3", pose: "thrust", dur: 1.5 },
	{ t: 20.5, kind: "lines", dur: 3 },
	{ t: 23.4, kind: "pose", actor: "bai", pose: "slashWindup", dur: 0.2, ease: "out" },
	{ t: 23.75, kind: "pose", actor: "bai", pose: "slashFollow", dur: 0.12, ease: "back" },
	{ t: 23.75, kind: "sfx", name: "slash" },
	{ t: 23.75, kind: "vfx", name: "slash", at: v(-7, 4.5, -5), to: v(7, 2.5, -6), color: QI },
	{ t: 23.8, kind: "impact", strength: 1 },
	{ t: 23.8, kind: "vfx", name: "burst", at: v(-3.5, 3, -5.5), color: GOLD },
	{ t: 23.82, kind: "vfx", name: "burst", at: v(0, 3, -6.5), color: GOLD },
	{ t: 23.84, kind: "vfx", name: "burst", at: v(3.5, 3, -5.5), color: GOLD },
	{ t: 23.85, kind: "hide", actor: "s1" },
	{ t: 23.85, kind: "hide", actor: "s2" },
	{ t: 23.85, kind: "hide", actor: "s3" },
	{ t: 23.9, kind: "speed", scale: 0.35 },
	{ t: 24, kind: "vfx", name: "ring", at: v(0, 0.3, 0), scale: 36, color: QI },
	{ t: 24.6, kind: "speed", scale: 1 },
	{ t: 25, kind: "pose", actor: "bai", pose: "guard", dur: 1, ease: "inOut" },

	// Serbuan kedua dari tiga arah + tebasan putar
	{ t: 26.8, kind: "sub", who: "Heavenly Commander", text: "All of you. Bring him down!", dur: 2.5 },
	{ t: 27, kind: "move", actor: "s4", to: at(-4, 0, -1, 0, 0), dur: 1.9, ease: "in", ghost: true },
	{ t: 27, kind: "move", actor: "s5", to: at(4, 0, -1, 0, 0), dur: 1.9, ease: "in", ghost: true },
	{ t: 27, kind: "move", actor: "s6", to: at(0, 0, 4.5, 0, 0), dur: 1.9, ease: "in", ghost: true },
	{ t: 27.5, kind: "pose", actor: "s4", pose: "thrust", dur: 1 },
	{ t: 27.5, kind: "pose", actor: "s5", pose: "thrust", dur: 1 },
	{ t: 27.5, kind: "pose", actor: "s6", pose: "thrust", dur: 1 },
	{ t: 28.9, kind: "pose", actor: "bai", pose: "slashWindup", dur: 0.15, ease: "out" },
	{ t: 29.05, kind: "pose", actor: "bai", pose: "slashFollow", dur: 0.1, ease: "back" },
	{ t: 29.05, kind: "move", actor: "bai", to: spin(120), dur: 0.1 },
	{ t: 29.15, kind: "move", actor: "bai", to: spin(240), dur: 0.1 },
	{ t: 29.25, kind: "move", actor: "bai", to: spin(360), dur: 0.1 },
	{ t: 29.1, kind: "sfx", name: "slash" },
	{ t: 29.1, kind: "vfx", name: "ring", at: v(0, 3, 0), scale: 22, color: QI },
	{ t: 29.15, kind: "vfx", name: "slash", at: v(-5, 3.5, 3), to: v(-5, 2.5, -4), color: QI },
	{ t: 29.2, kind: "vfx", name: "slash", at: v(5, 3, -4), to: v(4, 3.5, 4), color: QI },
	{ t: 29.25, kind: "impact", strength: 1.2 },
	{ t: 29.25, kind: "vfx", name: "burst", at: v(-4, 3, -1), color: GOLD },
	{ t: 29.27, kind: "vfx", name: "burst", at: v(4, 3, -1), color: GOLD },
	{ t: 29.29, kind: "vfx", name: "burst", at: v(0, 3, 4.5), color: GOLD },
	{ t: 29.3, kind: "hide", actor: "s4" },
	{ t: 29.3, kind: "hide", actor: "s5" },
	{ t: 29.3, kind: "hide", actor: "s6" },
	{ t: 29.3, kind: "speed", scale: 0.3 },
	{ t: 29.9, kind: "speed", scale: 1 },
	{ t: 30, kind: "pose", actor: "bai", pose: "guard", dur: 0.8, ease: "inOut" },

	// Lompat ke langit, tebasan raksasa menghempas seluruh pasukan
	{ t: 31.2, kind: "pose", actor: "bai", pose: "crouch", dur: 0.35, ease: "out" },
	{ t: 31.6, kind: "sfx", name: "whoosh" },
	{ t: 31.6, kind: "pose", actor: "bai", pose: "guard", dur: 0.4, ease: "out" },
	{ t: 31.6, kind: "move", actor: "bai", to: at(0, 35, -30, 0, -200), dur: 1.6, ease: "expoOut", ghost: true },
	{ t: 31.6, kind: "vfx", name: "debris", at: v(0, 0, 0) },
	{ t: 31.6, kind: "vfx", name: "ring", at: v(0, 0.3, 0), scale: 30, color: SALT },
	{ t: 31.65, kind: "shake", mag: 0.8, dur: 0.5 },
	{ t: 33.6, kind: "pose", actor: "bai", pose: "slashWindup", dur: 0.5, ease: "out" },
	{ t: 34.3, kind: "pose", actor: "bai", pose: "slashFollow", dur: 0.14, ease: "back" },
	{ t: 34.3, kind: "sfx", name: "slash" },
	{ t: 34.3, kind: "vfx", name: "slash", at: v(-90, 75, -150), to: v(90, 35, -150), dur: 1.2, color: QI },
	{ t: 34.4, kind: "impact", strength: 1.6 },
	{ t: 34.5, kind: "vfx", name: "collapse", at: v(0, 40, -60), target: "Army", dur: 2.6 },
	{ t: 34.55, kind: "vfx", name: "burst", at: v(0, 58, -100), scale: 2, color: GOLD },
	{ t: 34.55, kind: "hide", actor: "commander" },
	{ t: 34.6, kind: "vfx", name: "burst", at: v(-30, 55, -150), scale: 4, color: GOLD },
	{ t: 34.7, kind: "vfx", name: "burst", at: v(10, 48, -165), scale: 4, color: GOLD },
	{ t: 34.8, kind: "vfx", name: "burst", at: v(40, 42, -150), scale: 4, color: GOLD },
	{ t: 34.6, kind: "shake", mag: 1.4, dur: 1.2 },
	{ t: 35.2, kind: "speed", scale: 0.4 },
	{ t: 36, kind: "speed", scale: 1 },
	{ t: 36.5, kind: "pose", actor: "bai", pose: "guard", dur: 1.4, ease: "inOut" },

	// Langit kosong. Sosok diam muncul
	{ t: 38, kind: "music", name: "prologSilence", volume: 0.35, fade: 2 },
	{ t: 40.8, kind: "vfx", name: "burst", at: v(0, 38, -44), scale: 2, color: WHITE },
	{ t: 40.8, kind: "vfx", name: "ring", at: v(0, 38, -44), normal: v(0, 0, 1), scale: 18, color: WHITE },
	{ t: 41, kind: "show", actor: "figure" },
	{ t: 41, kind: "pose", actor: "figure", pose: "handsBehind", dur: 0 },
	{ t: 42.6, kind: "sub", who: "Bai Wuji", text: "...You.", dur: 2 },
	{ t: 46.5, kind: "pose", actor: "bai", pose: "thrust", dur: 0.2, ease: "back" },
	{ t: 46.5, kind: "move", actor: "bai", to: at(0, 35, -35.5, 0, -100), dur: 0.35, ease: "expoOut", ghost: true },
	{ t: 46.5, kind: "sfx", name: "whoosh" },
	{ t: 46.75, kind: "pose", actor: "figure", pose: "twoFinger", dur: 0.15, ease: "out" },
	{ t: 47, kind: "impact", strength: 1.4 },
	{ t: 47, kind: "sfx", name: "clash" },
	{ t: 47, kind: "vfx", name: "ring", at: v(0, 38.5, -42.3), normal: v(0, 0, 1), scale: 26, color: WHITE },
	{ t: 47.05, kind: "speed", scale: 0.12 },
	{ t: 47.6, kind: "speed", scale: 1 },
	{ t: 49.5, kind: "sfx", name: "crack" },
	{ t: 51.5, kind: "sfx", name: "crack" },
	{ t: 52.8, kind: "shake", mag: 0.25, dur: 1.2 },

	// Pedang patah
	{ t: 54, kind: "fade", to: 0.25, dur: 0.05, color: WHITE },
	{ t: 54.08, kind: "fade", to: 0, dur: 0.7, color: WHITE },
	{ t: 54, kind: "break", actor: "bai" },
	{ t: 54, kind: "sfx", name: "shatter" },
	{ t: 54, kind: "impact", strength: 2 },
	{ t: 54, kind: "pose", actor: "bai", pose: "fallBack", dur: 0.15, ease: "out" },
	{ t: 54, kind: "move", actor: "bai", to: at(0, 20, 2, 0, -100), dur: 1.1, ease: "expoOut", ghost: true },
	{ t: 54.05, kind: "vfx", name: "burst", at: v(0, 38.5, -42), scale: 2, color: QI },
	{ t: 54.2, kind: "speed", scale: 0.4 },
	{ t: 54.8, kind: "speed", scale: 1 },
	{ t: 55.2, kind: "move", actor: "bai", to: at(0, 0, 12, 0, -100), dur: 1.3, ease: "in" },
	{ t: 56.5, kind: "vfx", name: "debris", at: v(0, 0, 12) },
	{ t: 56.5, kind: "vfx", name: "ring", at: v(0, 0.3, 12), scale: 30, color: SALT },
	{ t: 56.5, kind: "shake", mag: 1, dur: 0.6 },
	{ t: 56.5, kind: "sfx", name: "thud" },
	{ t: 56.6, kind: "pose", actor: "bai", pose: "kneel", dur: 0.5, ease: "out" },
	{ t: 60.5, kind: "pose", actor: "bai", pose: "kneelLookUp", dur: 1.5, ease: "inOut" },
	{ t: 63.3, kind: "sub", who: "Bai Wuji", text: "Who... are you?", dur: 2.4 },
	{ t: 65.4, kind: "vfx", name: "burst", at: v(0, 38, -44), scale: 1.5, color: WHITE },
	{ t: 65.5, kind: "hide", actor: "figure" },

	// Serpihan jatuh ke dunia fana
	{ t: FALL_T0, kind: "vfx", name: "fall", at: P0, via: P1, to: P2, dur: FALL_T1 - FALL_T0, color: QI },
	{ t: 66.2, kind: "sub", text: "No one answered. The sky only closed its eye.", dur: 3.5 },
	{ t: 70, kind: "sub", text: "One shard of his sword fell through the clouds...", dur: 3.5 },
	{ t: cloudT, kind: "vfx", name: "ring", at: shardAt(cloudT), scale: 70, color: WHITE },
	{ t: cloudT, kind: "shake", mag: 0.4, dur: 0.5 },
	{ t: cloudT, kind: "sfx", name: "whoosh" },
	{ t: 74.5, kind: "sub", text: "...into the world of mortals, and waited.", dur: 4 },
	{ t: FALL_T1, kind: "vfx", name: "burst", at: P2, scale: 3, color: QI },
	{ t: FALL_T1, kind: "vfx", name: "ring", at: P2.add(v(0, 0.5, 0)), scale: 25, color: QI },
	{ t: 83, kind: "fade", to: 1, dur: 2.5 },
	{ t: 85.5, kind: "title", text: "DUST THAT DEFIES THE SKY", sub: "Prologue", dur: 4.5 },
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
		grade: { Contrast: 0.15, Saturation: 0.05, TintColor: Color3.fromRGB(255, 244, 230) },
		bloom: { Intensity: 0.6, Size: 28, Threshold: 1.6 },
		handheld: 0.25,
	},
	build,
	actors: [
		{ id: "bai", look: "template", template: "BaiWuji", color: Color3.fromRGB(235, 235, 240), weapon: "jian", ghostColor: QI, start: at(0, 0, 0, 0, -100) },
		{ id: "commander", look: "silhouette", color: GOLD, material: Enum.Material.Neon, start: at(0, 55, -100, 0, 0) },
		{ id: "s1", look: "silhouette", color: GOLD, material: Enum.Material.Neon, weapon: "jian", ghostColor: GOLD, start: at(-10, 0, -60, 0, 0) },
		{ id: "s2", look: "silhouette", color: GOLD, material: Enum.Material.Neon, weapon: "jian", ghostColor: GOLD, start: at(0, 0, -64, 0, 0) },
		{ id: "s3", look: "silhouette", color: GOLD, material: Enum.Material.Neon, weapon: "jian", ghostColor: GOLD, start: at(10, 0, -60, 0, 0) },
		{ id: "s4", look: "silhouette", color: GOLD, material: Enum.Material.Neon, weapon: "jian", ghostColor: GOLD, start: at(-30, 0, -10, 0, 0) },
		{ id: "s5", look: "silhouette", color: GOLD, material: Enum.Material.Neon, weapon: "jian", ghostColor: GOLD, start: at(30, 0, -10, 0, 0) },
		{ id: "s6", look: "silhouette", color: GOLD, material: Enum.Material.Neon, weapon: "jian", ghostColor: GOLD, start: at(0, 0, 40, 0, 0) },
		{ id: "figure", look: "silhouette", color: VOID, material: Enum.Material.SmoothPlastic, start: at(0, 35, -44, 0, 0), hidden: true },
	],
	camera,
	events,
};
