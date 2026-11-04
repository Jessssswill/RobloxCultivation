// Aktor cutscene: salinan rig R15 yang digerakin lewat HumanoidRootPart (anchored) + sendi. Sendi bisa Motor6D (rig lama)
// atau AnimationConstraint (rig baru Roblox, dipakai place ini: dicek 4 Nov, Mannequin & avatar pemain 0 Motor6D).
// Gak butuh animasi yang di-upload, jadi langsung jalan di game asli. Semua lokal di client.
//
// Biar gak kaku kayak slide PowerPoint:
// - Tiap sendi ditarik pegas ke pose target (ada momentum + lewat dikit), ujung badan (kepala, siku, pergelangan)
//   lebih telat dari pinggang = gerak susulan.
// - Lapisan "hidup" di atasnya: napas, goyang kecil acak, mantul siaga, melayang di udara.
// - Pindah tempat di tanah = kaki lari beneran (fase langkah ikut jarak), badan condong ke arah gerak.
// - Rambut, jubah belakang, dan rumbai pedang bergoyang ikut percepatan badan.

import { Players, ReplicatedStorage } from "@rbxts/services";
import { TEX } from "shared/cutscene/audio";
import { ease } from "shared/cutscene/ease";
import { jointCFrame, jointVec, POSES } from "shared/cutscene/poses";
import { ActorDef, Ease } from "shared/cutscene/types";
import { Quality } from "./quality";

const ID = new CFrame();
const UP = new Vector3(0, 1, 0);
const GRAVITY = 42;
const STRIKES = new Set(["slashFollow", "thrust", "spinSlash", "downSlash"]);
/** Pose siaga: badan mantul pelan kayak siap tarung. */
const ALERT = new Set(["guard", "drawStance", "spinReady"]);
const ARM_JOINTS = new Set(["RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow"]);
const QI = Color3.fromRGB(190, 225, 255);
const GILT = Color3.fromRGB(214, 172, 92);
const STEEL = Color3.fromRGB(218, 224, 232);
const CRIMSON = Color3.fromRGB(150, 26, 26);
const GOLD = Color3.fromRGB(255, 205, 110);

/** Kecepatan relatif tiap sendi ngejar target. Pinggang duluan, kepala & tangan telat = gerak susulan. */
const GAIN: Record<string, number> = {
	Root: 1.15,
	Waist: 1.1,
	Neck: 0.8,
	RightShoulder: 1,
	LeftShoulder: 0.92,
	RightElbow: 0.85,
	LeftElbow: 0.8,
	RightWrist: 0.72,
	LeftWrist: 0.68,
	RightHip: 1,
	LeftHip: 1,
	RightKnee: 0.9,
	LeftKnee: 0.9,
	RightAnkle: 0.8,
	LeftAnkle: 0.8,
};

interface Joint {
	name: string;
	motor?: Motor6D;
	ac?: AnimationConstraint;
	c0: CFrame;
	/** [rx, ry, rz derajat, dy stud] sekarang, kecepatan, dan target. */
	x: number[];
	v: number[];
	to: number[];
	w: number;
	z: number;
	gain: number;
}

/** Goyangan bandul (rambut, jubah, rumbai): 2 sudut yang ditarik pegas ke arah kebalikan percepatan. */
interface Sway {
	part: BasePart;
	apply: (ax: number, az: number) => void;
	x: number[];
	v: number[];
	to: number[];
	lastPos: Vector3;
	lastVel: Vector3;
	k: number;
	max: number;
	flutter: number;
}

/** Satu langkah pegas teredam, rumus pasti (stabil di FPS berapa pun). Ngubah x[i] dan v[i] langsung. */
function springStep(x: number[], v: number[], to: number[], i: number, w: number, z: number, dt: number) {
	const c1 = x[i] - to[i];
	const v0 = v[i];
	if (z >= 0.999) {
		const c2 = v0 + w * c1;
		const e = math.exp(-w * dt);
		x[i] = to[i] + (c1 + c2 * dt) * e;
		v[i] = (c2 - w * (c1 + c2 * dt)) * e;
		return;
	}
	const wd = w * math.sqrt(1 - z * z);
	const c2 = (v0 + z * w * c1) / wd;
	const e = math.exp(-z * w * dt);
	const cs = math.cos(wd * dt);
	const sn = math.sin(wd * dt);
	const a = c1 * cs + c2 * sn;
	x[i] = to[i] + e * a;
	v[i] = e * (-z * w * a + wd * (c2 * cs - c1 * sn));
}

/** Easing pose jadi redaman pegas: "back" mantul (lewat target lalu balik), "inOut" mulus tanpa lewat. */
function damping(e: Ease | undefined) {
	if (e === "back") return 0.5;
	if (e === "out" || e === "expoOut") return 0.78;
	if (e === "inOut" || e === "in") return 1;
	return 0.85;
}

function cloneCharacter(): Model | undefined {
	const char = Players.LocalPlayer.Character;
	if (!char) return undefined;
	const was = char.Archivable;
	char.Archivable = true;
	const copy = char.Clone();
	char.Archivable = was;
	return copy;
}

/** Ambil model sumber. Hasil kedua: perlu dicat (mannequin / siluet). */
function source(def: ActorDef): [Model | undefined, boolean] {
	const rigs = ReplicatedStorage.FindFirstChild("CutsceneRigs");
	if (def.look === "player") {
		const own = cloneCharacter();
		if (own) return [own, false];
	}
	if (def.look === "template" && def.template !== undefined) {
		const t = rigs?.FindFirstChild(def.template);
		if (t && t.IsA("Model")) return [t.Clone(), false];
	}
	const mannequin = rigs?.FindFirstChild("Mannequin");
	if (mannequin && mannequin.IsA("Model")) return [mannequin.Clone(), true];
	return [cloneCharacter(), def.look !== "player"];
}

function paint(model: Model, color: Color3, material: Enum.Material, silhouette: boolean) {
	for (const d of model.GetDescendants()) {
		if (d.IsA("BodyColors") || d.IsA("SurfaceAppearance")) d.Destroy();
		else if (silhouette && (d.IsA("Accessory") || d.IsA("Clothing") || d.IsA("ShirtGraphic") || d.IsA("Decal"))) d.Destroy();
	}
	for (const d of model.GetDescendants()) {
		if (!d.IsA("BasePart") || d.Name === "HumanoidRootPart") continue;
		d.Color = color;
		d.Material = material;
		if (silhouette && d.IsA("MeshPart")) pcall(() => (d.TextureID = ""));
	}
}

export class Actor {
	readonly model: Model;
	readonly root: BasePart;
	readonly ghostColor: Color3;
	visible = true;
	liveGhosts = 0;
	lastGhost = -math.huge;
	ghosting = false;
	/** Diam total: napas, goyang, mantul siaga, dan melayang dimatiin (Sosok Diam, momen waktu berhenti). Pegas pose tetap jalan. */
	still = false;
	/** Emitter milik aktor (aura, debu luruh), didaftarin ke runtime biar ikut slow-mo. */
	readonly fx: ParticleEmitter[] = [];
	/** Dipanggil kalau aktor bikin emitter baru di tengah cutscene. */
	onEmitter?: (e: ParticleEmitter) => void;

	private parent: Instance;
	private origin: CFrame;
	private seed: number;
	private lift: CFrame;
	private feet: CFrame;
	private joints: Joint[] = [];
	private poseName = "idle";
	private poseArms = false;
	private lastNow = 0;
	private energy = 0;

	private moving = false;
	private mFrom = ID;
	private mTo = ID;
	private mT0 = 0;
	private mDur = 1e-3;
	private mEase?: Ease;
	private mSpin = 0;
	private mFlip = 0;
	private lastPos: Vector3;
	private velS = Vector3.zero;
	private accS = Vector3.zero;
	private phase = 0;

	private knocked = false;
	private kT0 = 0;
	private kStart = ID;
	private kVel = Vector3.zero;
	private kSpin = Vector3.zero;
	private kFade?: number;
	private fading?: Array<[BasePart | Decal, number]>;
	private highlight?: Highlight;

	private blade?: BasePart;
	private bladeWeld?: Weld;
	private edge?: BasePart;
	private edgeWeld?: Weld;
	private trail?: Trail;
	private qiTrail?: Trail;
	private trailOff = 0;
	private swordParts: BasePart[] = [];
	private swordFx: Array<ParticleEmitter | PointLight> = [];
	private bladeGlow?: BasePart;
	private wings?: BasePart;
	private tipAtt?: Attachment;
	private baseAtt?: Attachment;
	private auraOn = false;
	private animator?: Animator;
	/** Jumlah animasi upload yang lagi main. Selama ada, sendi dipegang Animator, pose pegas berhenti nulis. */
	private animTracks = 0;

	private ghostParts: BasePart[] = [];
	private auraFx: ParticleEmitter[] = [];
	private auraLight?: PointLight;
	private sways: Sway[] = [];

	static create(def: ActorDef, parent: Instance, origin: CFrame, q: Quality): Actor | undefined {
		const [model, needsPaint] = source(def);
		if (!model) return undefined;
		return new Actor(def, model, needsPaint, parent, origin, q);
	}

	private constructor(def: ActorDef, model: Model, needsPaint: boolean, parent: Instance, origin: CFrame, q: Quality) {
		this.model = model;
		this.parent = parent;
		this.origin = origin;
		this.ghostColor = def.ghostColor ?? QI;
		this.seed = new Random().NextNumber(0, 100);
		model.Name = `Actor_${def.id}`;

		for (const d of model.GetDescendants()) {
			if (d.IsA("LuaSourceContainer") || d.IsA("Tool") || d.IsA("ForceField")) d.Destroy();
		}
		if (needsPaint || def.look === "silhouette") {
			paint(model, def.color ?? Color3.fromRGB(200, 200, 205), def.material ?? Enum.Material.SmoothPlastic, def.look === "silhouette");
		}

		const hum = model.FindFirstChildOfClass("Humanoid");
		if (hum) {
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff;
			hum.BreakJointsOnDeath = false;
			hum.RequiresNeck = false;
			hum.EvaluateStateMachine = false;
			const animator = hum.FindFirstChildOfClass("Animator");
			if (animator) for (const track of animator.GetPlayingAnimationTracks()) track.Stop(0);
			this.animator = animator;
		}
		const root = (model.FindFirstChild("HumanoidRootPart") as BasePart | undefined) ?? model.FindFirstChildWhichIsA("BasePart", true)!;
		this.root = root;
		for (const d of model.GetDescendants()) {
			if (d.IsA("BasePart")) {
				d.Anchored = d === root;
				d.CanCollide = false;
				d.CanQuery = false;
				d.CanTouch = false;
				d.Massless = true;
				// Baju berlapis (WrapLayer) gak ikut bayangan: kalau di-clone bentuknya balik ke mesh mentah
				if (d !== root && d.Transparency < 0.99 && !d.FindFirstChildOfClass("WrapLayer")) this.ghostParts.push(d);
			} else if (d.IsA("Motor6D")) {
				this.addJoint(d.Name, d, undefined, d.C0);
				d.Transform = ID;
			} else if (d.IsA("AnimationConstraint")) {
				// Pose lewat Transform (setara C0 * rot di Motor6D). Kinematic = kaku kayak Motor6D, gak ikut fisika
				d.IsKinematic = true;
				d.Transform = ID;
				this.addJoint(d.Name, undefined, d, ID);
			} else if (d.IsA("BallSocketConstraint")) {
				d.Enabled = false;
			}
		}
		const liftY = hum ? root.Size.Y / 2 + hum.HipHeight : 3;
		this.lift = new CFrame(0, liftY, 0);
		this.feet = origin.mul(def.start);
		this.lastPos = this.feet.Position;
		root.CFrame = this.feet.mul(this.lift);

		const sword = def.sword !== undefined ? this.attachSword(def.sword, def.swordScale ?? 0.8, q) : false;
		if (!sword && def.weapon) this.attachWeapon(def.weapon);
		this.setupSway(q);
		if (def.outline && (q.tier === 2 || (q.tier === 1 && def.outline.key === true))) {
			const h = new Instance("Highlight");
			h.FillTransparency = 1;
			h.OutlineColor = def.outline.color;
			h.OutlineTransparency = def.outline.alpha ?? 0.4;
			h.DepthMode = Enum.HighlightDepthMode.Occluded;
			h.Parent = model;
			this.highlight = h;
		}
		if (def.aura && q.tier >= 1) this.makeAura(def.aura, q);
		model.Parent = parent;
		if (def.hidden) this.setVisible(false);
	}

	private addJoint(name: string, motor: Motor6D | undefined, ac: AnimationConstraint | undefined, c0: CFrame) {
		this.joints.push({ name, motor, ac, c0, x: [0, 0, 0, 0], v: [0, 0, 0, 0], to: [0, 0, 0, 0], w: 8, z: 1, gain: GAIN[name] ?? 0.9 });
	}

	/** Rambut, jubah belakang, selempang pinggang: bandul di titik tempelnya. */
	private setupSway(q: Quality) {
		if (q.tier === 0) return;
		for (const acc of this.model.GetChildren()) {
			if (!acc.IsA("Accessory")) continue;
			const handle = acc.FindFirstChild("Handle");
			if (!handle || !handle.IsA("BasePart") || handle.FindFirstChildOfClass("WrapLayer")) continue;
			const kind = acc.AccessoryType;
			const settings =
				kind === Enum.AccessoryType.Back
					? { max: 20, k: 0.09, flutter: 2.5 }
					: kind === Enum.AccessoryType.Hair
						? { max: 6, k: 0.04, flutter: 0.6 }
						: kind === Enum.AccessoryType.Waist
							? { max: 12, k: 0.07, flutter: 1.5 }
							: undefined;
			if (!settings) continue;
			const weld = handle.FindFirstChild("AccessoryWeld");
			if (!weld || !weld.IsA("Weld")) continue;
			const onC1 = weld.Part0 === handle;
			const body = onC1 ? weld.Part1 : weld.Part0;
			if (!body) continue;
			const base = onC1 ? weld.C1 : weld.C0;
			this.sways.push({
				part: body,
				apply: (ax, az) => {
					const r = CFrame.Angles(math.rad(ax), 0, math.rad(az));
					if (onC1) weld.C1 = base.mul(r);
					else weld.C0 = base.mul(r);
				},
				x: [0, 0],
				v: [0, 0],
				to: [0, 0],
				lastPos: body.Position,
				lastVel: Vector3.zero,
				...settings,
			});
		}
	}

	/** Aura qi naik dari badan (mati dulu, nyala lewat setAura). */
	private makeAura(color: Color3, q: Quality) {
		const torso = (this.model.FindFirstChild("UpperTorso") as BasePart | undefined) ?? this.root;
		const add = (props: Partial<WritableInstanceProperties<ParticleEmitter>>) => {
			const e = new Instance("ParticleEmitter");
			e.Enabled = false;
			e.LightEmission = 1;
			e.LightInfluence = 0;
			e.EmissionDirection = Enum.NormalId.Top;
			for (const [k, v] of pairs(props as Record<string, unknown>)) (e as unknown as Record<string, unknown>)[k] = v;
			e.Parent = torso;
			this.auraFx.push(e);
			this.fx.push(e);
		};
		add({
			Texture: TEX.glow,
			Color: new ColorSequence(color, new Color3(1, 1, 1)),
			Size: new NumberSequence([new NumberSequenceKeypoint(0, 1.8), new NumberSequenceKeypoint(1, 0)]),
			Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0.45), new NumberSequenceKeypoint(1, 1)]),
			Lifetime: new NumberRange(0.5, 0.9),
			Speed: new NumberRange(2, 5),
			SpreadAngle: new Vector2(30, 30),
			Acceleration: new Vector3(0, 8, 0),
			Rate: math.floor(36 * q.particles),
		});
		if (q.tier === 2) {
			add({
				Texture: TEX.smokeFlip,
				FlipbookLayout: Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode: Enum.ParticleFlipbookMode.OneShot,
				Color: new ColorSequence(color),
				LightEmission: 0.8,
				Size: new NumberSequence([new NumberSequenceKeypoint(0, 1.2), new NumberSequenceKeypoint(1, 3.2)]),
				Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0.55), new NumberSequenceKeypoint(1, 1)]),
				Lifetime: new NumberRange(0.5, 0.8),
				Speed: new NumberRange(1, 3),
				Rotation: new NumberRange(0, 360),
				Acceleration: new Vector3(0, 10, 0),
				Rate: 14,
			});
			const light = new Instance("PointLight");
			light.Color = color;
			light.Range = 12;
			light.Brightness = 2;
			light.Enabled = false;
			light.Parent = torso;
			this.auraLight = light;
		}
	}

	/** Aura + pedang ikut bercahaya. */
	setAura(on: boolean) {
		this.auraOn = on;
		for (const e of this.auraFx) e.Enabled = on;
		if (this.auraLight) this.auraLight.Enabled = on;
		if (this.bladeGlow) this.bladeGlow.Transparency = on ? 0.5 : 1;
	}

	/**
	 * Pedang mesh asli (model senjata yang udah ada di place, disalin server ke CutsceneRigs). Dipegang lurus ke -Z tangan,
	 * sama kayak jian part lama, jadi pose lama tetap cocok.
	 */
	private attachSword(name: string, scale: number, q: Quality): boolean {
		const hand = this.model.FindFirstChild("RightHand") as BasePart | undefined;
		const src = ReplicatedStorage.FindFirstChild("CutsceneRigs")?.FindFirstChild(name);
		if (!hand || !src || !src.IsA("Model")) return false;
		const sword = src.Clone();
		const handle = sword.FindFirstChild("Handle");
		if (!handle || !handle.IsA("BasePart")) {
			sword.Destroy();
			return false;
		}
		sword.PrimaryPart = handle;
		pcall(() => sword.ScaleTo(scale));
		const gripAtt = hand.FindFirstChild("RightGripAttachment") as Attachment | undefined;
		const gripPos = gripAtt ? gripAtt.Position : new Vector3(0, -0.17, 0);
		const grip = new CFrame(gripPos).mul(CFrame.Angles(-math.pi / 2, 0, 0));
		sword.PivotTo(hand.CFrame.mul(grip));
		for (const d of sword.GetDescendants()) {
			if (d.IsA("BasePart")) {
				d.Anchored = false;
				d.CanCollide = false;
				d.CanQuery = false;
				d.CanTouch = false;
				d.Massless = true;
				d.CastShadow = false;
				this.swordParts.push(d);
				if (d.Transparency < 0.99) this.ghostParts.push(d);
			} else if (d.IsA("Trail")) {
				d.Enabled = false;
				if (d.Name === "QiTrail") this.qiTrail = d;
				else this.trail = d;
			} else if (d.IsA("ParticleEmitter")) {
				// Kilau kecil di bilah tetap nyala (mewah), sisanya cuma di grafik tinggi
				d.Enabled = d.Name === "VFX_Sparks" ? true : q.tier === 2 && d.Enabled;
				if (d.Enabled) d.Rate = d.Rate * q.particles;
				this.fx.push(d);
				this.swordFx.push(d);
			} else if (d.IsA("PointLight")) {
				d.Enabled = q.lights;
				this.swordFx.push(d);
			} else if (d.IsA("Attachment")) {
				if (d.Name === "BladeTip") this.tipAtt = d;
				else if (d.Name === "BladeBase") this.baseAtt = d;
			} else if (d.IsA("Bone") && q.tier >= 1) {
				// Bone pertama di rantai (induknya MeshPart rumbai)
				const owner = d.Parent;
				if (owner && owner.IsA("BasePart")) this.addTassel(owner, d);
			}
		}
		this.bladeGlow = sword.FindFirstChild("BladeGlow") as BasePart | undefined;
		this.wings = sword.FindFirstChild("LightWings") as BasePart | undefined;
		if (this.bladeGlow) this.bladeGlow.Transparency = 1;
		if (this.wings) this.wings.Transparency = 1;
		const weld = new Instance("Weld");
		weld.Part0 = hand;
		weld.Part1 = handle;
		weld.C0 = grip;
		weld.Parent = handle;
		sword.Name = "Sword";
		sword.Parent = this.model;
		return true;
	}

	/** Rumbai pedang (rantai Bone): makin ke ujung makin besar goyangnya. */
	private addTassel(part: BasePart, first: Bone) {
		const chain: Bone[] = [];
		let b: Instance | undefined = first;
		while (b && b.IsA("Bone")) {
			chain.push(b);
			b = b.FindFirstChildWhichIsA("Bone");
		}
		this.sways.push({
			part,
			apply: (ax, az) => {
				chain.forEach((bone, i) => {
					const f = 0.22 + 0.06 * i;
					bone.Transform = CFrame.Angles(math.rad(ax * f), 0, math.rad(az * f));
				});
			},
			x: [0, 0],
			v: [0, 0],
			to: [0, 0],
			lastPos: part.Position,
			lastVel: Vector3.zero,
			k: 0.16,
			max: 70,
			flutter: 4,
		});
	}

	/** Senjata part (cadangan kalau pedang mesh gak ada): jian atau tombak, dengan trail. */
	private attachWeapon(kind: "jian" | "spear") {
		const hand = (this.model.FindFirstChild("RightHand") ?? this.model.FindFirstChild("Right Arm")) as BasePart | undefined;
		if (!hand) return;
		const grip = new CFrame(0, -0.25, 0);
		const make = (name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape?: Enum.PartType): [Part, Weld] => {
			const p = new Instance("Part");
			p.Name = name;
			p.Size = size;
			p.Color = color;
			p.Material = material;
			if (shape) p.Shape = shape;
			p.CanCollide = false;
			p.CanQuery = false;
			p.CanTouch = false;
			p.Massless = true;
			p.CastShadow = false;
			p.CFrame = hand.CFrame.mul(grip).mul(offset);
			const w = new Instance("Weld");
			w.Part0 = hand;
			w.Part1 = p;
			w.C0 = grip.mul(offset);
			w.Parent = p;
			p.Parent = this.model;
			this.ghostParts.push(p);
			return [p, w];
		};
		let blade: Part;
		let bladeWeld: Weld;
		let edge: Part;
		let edgeWeld: Weld;
		if (kind === "jian") {
			make("Grip", new Vector3(0.2, 0.2, 1), new CFrame(0, 0, 0.1), Color3.fromRGB(74, 26, 22), Enum.Material.Fabric);
			make("Pommel", new Vector3(0.3, 0.3, 0.3), new CFrame(0, 0, 0.68), GILT, Enum.Material.Metal, Enum.PartType.Ball);
			make("Tassel", new Vector3(0.09, 0.09, 0.7), new CFrame(0, -0.32, 0.86).mul(CFrame.Angles(math.rad(70), 0, 0)), CRIMSON, Enum.Material.Fabric);
			make("Guard", new Vector3(0.16, 0.95, 0.22), new CFrame(0, 0, -0.5), GILT, Enum.Material.Metal);
			[blade, bladeWeld] = make("Blade", new Vector3(0.06, 0.24, 4.4), new CFrame(0, 0, -2.8), STEEL, Enum.Material.Metal);
			[edge, edgeWeld] = make("Edge", new Vector3(0.03, 0.05, 4.3), new CFrame(0, 0.13, -2.8), QI, Enum.Material.Neon);
		} else {
			make("Shaft", new Vector3(0.16, 0.16, 8.4), new CFrame(0, 0, -1.6), Color3.fromRGB(92, 30, 24), Enum.Material.Wood);
			make("Butt", new Vector3(0.2, 0.2, 0.45), new CFrame(0, 0, 2.55), GILT, Enum.Material.Metal);
			make("Collar", new Vector3(0.24, 0.24, 0.32), new CFrame(0, 0, -5.75), GILT, Enum.Material.Metal);
			make("Tassel", new Vector3(0.55, 0.55, 0.55), new CFrame(0, -0.18, -5.5), CRIMSON, Enum.Material.Fabric, Enum.PartType.Ball);
			[blade, bladeWeld] = make("Blade", new Vector3(0.06, 0.34, 1.3), new CFrame(0, 0, -6.55), STEEL, Enum.Material.Metal);
			[edge, edgeWeld] = make("Edge", new Vector3(0.03, 0.05, 1.25), new CFrame(0, 0.17, -6.55), this.ghostColor, Enum.Material.Neon);
		}
		edge.Transparency = 0.3;
		blade.Reflectance = 0.25;

		const half = blade.Size.Z / 2;
		const a0 = new Instance("Attachment");
		a0.Position = new Vector3(0, 0, half * 0.9);
		a0.Parent = blade;
		const a1 = new Instance("Attachment");
		a1.Position = new Vector3(0, 0, -half);
		a1.Parent = blade;
		const trail = new Instance("Trail");
		trail.Attachment0 = a0;
		trail.Attachment1 = a1;
		trail.Lifetime = 0.18;
		trail.MinLength = 0.05;
		trail.LightEmission = 1;
		trail.LightInfluence = 0;
		trail.Color = new ColorSequence(new Color3(1, 1, 1), this.ghostColor);
		trail.Transparency = new NumberSequence(0.2, 1);
		trail.Enabled = false;
		trail.Parent = blade;

		this.blade = blade;
		this.bladeWeld = bladeWeld;
		this.edge = edge;
		this.edgeWeld = edgeWeld;
		this.trail = trail;
		this.tipAtt = a1;
		this.baseAtt = a0;
	}

	setPose(name: string, dur: number, e: Ease | undefined, now: number) {
		const pose = POSES[name] ?? {};
		this.poseName = name;
		this.poseArms = pose.RightShoulder !== undefined || pose.LeftShoulder !== undefined;
		const instant = dur <= 0.02;
		const w = math.clamp(4.4 / math.max(dur, 0.02), 2.5, 75);
		const z = damping(e);
		for (const j of this.joints) {
			const target = jointVec(pose[j.name]);
			for (let i = 0; i < 4; i++) {
				j.to[i] = target[i];
				if (instant) {
					j.x[i] = target[i];
					j.v[i] = 0;
				}
			}
			j.w = w * j.gain;
			// Ujung badan sedikit lebih "kenyal"
			j.z = z >= 0.999 ? 1 : z * (j.gain < 0.9 ? 0.9 : 1);
		}
		if (STRIKES.has(name)) {
			if (this.trail) this.trail.Enabled = true;
			if (this.qiTrail && this.auraOn) this.qiTrail.Enabled = true;
			this.trailOff = now + math.max(dur, 0.1) + 0.3;
		}
	}

	moveTo(feet: CFrame, dur: number, e: Ease | undefined, now: number, ghost: boolean, spin = 0, flip = 0) {
		this.mFrom = this.feet;
		this.mTo = feet;
		this.mT0 = now;
		this.mDur = math.max(dur, 1e-3);
		this.mEase = e;
		this.mSpin = spin;
		this.mFlip = flip;
		this.moving = true;
		this.ghosting = ghost;
	}

	/** Terhempas: lempar balistik + muter, luruh jadi debu cahaya kalau `fade` diisi. */
	knock(dir: Vector3, power: number, fade: number | undefined, now: number) {
		const rng = new Random();
		const flat = new Vector3(dir.X, 0, dir.Z);
		const d = flat.Magnitude > 0.01 ? flat.Unit : new Vector3(0, 0, 1);
		this.knocked = true;
		this.moving = false;
		this.kT0 = now;
		this.kStart = this.root.CFrame;
		this.kVel = d.mul(power).add(UP.mul(power * 0.45 + dir.Y * power));
		this.kSpin = new Vector3(rng.NextNumber(2, 5) * (rng.NextNumber() < 0.5 ? -1 : 1), rng.NextNumber(-3, 3), rng.NextNumber(-4, 4));
		this.kFade = fade;
		this.ghosting = false;
		this.setPose("hitFly", 0.1, "out", now);
	}

	/** Mainin animasi upload (event "anim"). Pose pegas berhenti nulis sendi sampai animasinya selesai. */
	playAnim(id: string, speed: number) {
		if (!this.animator) return;
		const anim = new Instance("Animation");
		anim.AnimationId = id;
		const track = this.animator.LoadAnimation(anim);
		this.animTracks += 1;
		track.Stopped.Once(() => (this.animTracks = math.max(0, this.animTracks - 1)));
		track.Play(0.1, 1, speed);
	}

	/** Sayap cahaya di pangkal pedang: 0 hilang, 1 penuh. */
	setWings(a: number) {
		if (this.wings) this.wings.Transparency = 1 - 0.85 * math.clamp(a, 0, 1);
	}

	bladeTip(): Vector3 | undefined {
		return this.tipAtt?.WorldPosition;
	}

	/**
	 * Patahin pedang. Pedang mesh pecah total (bagian disembunyiin, serpihan dibikin VFX), pedang part dipotong.
	 * Balikin [pangkal, ujung] bilah buat serpihan.
	 */
	breakBlade(): [Vector3, Vector3] | undefined {
		const tip = this.tipAtt?.WorldPosition;
		const base = this.baseAtt?.WorldPosition;
		if (!tip || !base) return undefined;
		if (this.swordParts.size() > 0) {
			for (const p of this.swordParts) p.Transparency = 1;
			for (const fx of this.swordFx) fx.Enabled = false;
		} else if (this.blade && this.bladeWeld) {
			const blade = this.blade;
			const len = blade.Size.Z * 0.35;
			const grip = new CFrame(0, -0.25, 0);
			blade.Size = new Vector3(blade.Size.X, blade.Size.Y, len);
			this.bladeWeld.C0 = grip.mul(new CFrame(0, 0, -0.6 - len / 2));
			if (this.edge && this.edgeWeld) {
				this.edge.Size = new Vector3(this.edge.Size.X, this.edge.Size.Y, len);
				this.edgeWeld.C0 = grip.mul(new CFrame(0, 0.13, -0.6 - len / 2));
			}
		}
		if (this.trail) this.trail.Enabled = false;
		if (this.qiTrail) this.qiTrail.Enabled = false;
		this.trail = undefined;
		this.qiTrail = undefined;
		this.tipAtt = undefined;
		return [base, tip];
	}

	setVisible(v: boolean) {
		this.visible = v;
		this.model.Parent = v ? this.parent : undefined;
	}

	/** Bagian badan yang kelihatan, buat bikin bayangan (afterimage). */
	parts(): readonly BasePart[] {
		return this.ghostParts;
	}

	update(now: number) {
		if (!this.visible) return;
		const dt = math.clamp(now - this.lastNow, 0, 0.1);
		this.lastNow = now;
		if (this.knocked) this.updateKnock(now);
		else this.updateRoot(now, dt);
		if (this.trail && this.trail.Enabled && now > this.trailOff) this.trail.Enabled = false;
		if (this.qiTrail && this.qiTrail.Enabled && now > this.trailOff) this.qiTrail.Enabled = false;
		this.updateJoints(now, dt);
		this.updateSway(now, dt);
	}

	private updateRoot(now: number, dt: number) {
		let spin = ID;
		if (this.moving) {
			const a = math.clamp((now - this.mT0) / this.mDur, 0, 1);
			const e = ease(this.mEase, a);
			this.feet = this.mFrom.Lerp(this.mTo, e);
			if (this.mSpin !== 0 || this.mFlip !== 0) spin = CFrame.Angles(math.rad(this.mFlip * e), math.rad(this.mSpin * e), 0);
			if (a >= 1) {
				this.moving = false;
				this.ghosting = false;
				// Putaran yang gak genap 360 jadi arah hadap baru
				if (this.mSpin % 360 !== 0) this.feet = this.mTo.mul(CFrame.Angles(0, math.rad(this.mSpin), 0));
				spin = ID;
			}
		}
		// Kecepatan + percepatan (dihaluskan) buat lari, condong badan, dan goyang jubah
		if (dt > 0) {
			const pos = this.feet.Position;
			const vel = pos.sub(this.lastPos).div(dt);
			this.lastPos = pos;
			const prev = this.velS;
			this.velS = prev.Lerp(vel, 1 - math.exp(-14 * dt));
			this.accS = this.accS.Lerp(this.velS.sub(prev).div(dt), 1 - math.exp(-10 * dt));
		}
		this.root.CFrame = this.feet.mul(this.lift).mul(spin);
	}

	private updateKnock(now: number) {
		const t = now - this.kT0;
		const p = this.kStart.Position.add(this.kVel.mul(t)).add(new Vector3(0, -0.5 * GRAVITY * t * t, 0));
		this.root.CFrame = new CFrame(p).mul(this.kStart.Rotation).mul(CFrame.Angles(this.kSpin.X * t, this.kSpin.Y * t, this.kSpin.Z * t));
		if (this.kFade === undefined) return;
		const a = math.clamp((t - 0.12) / this.kFade, 0, 1);
		if (a <= 0) return;
		if (!this.fading) {
			// Mulai luruh: simpan transparansi asli, semburkan debu emas dari badan
			this.fading = [];
			for (const d of this.model.GetDescendants()) {
				if ((d.IsA("BasePart") || d.IsA("Decal")) && d.Transparency < 1 && d !== this.root) this.fading.push([d, d.Transparency]);
			}
			const torso = (this.model.FindFirstChild("UpperTorso") as BasePart | undefined) ?? this.root;
			const dust = new Instance("ParticleEmitter");
			dust.Texture = TEX.glow;
			dust.Color = new ColorSequence(GOLD, new Color3(1, 1, 1));
			dust.LightEmission = 1;
			dust.LightInfluence = 0;
			dust.Size = new NumberSequence([new NumberSequenceKeypoint(0, 0.5), new NumberSequenceKeypoint(1, 0)]);
			dust.Transparency = new NumberSequence([new NumberSequenceKeypoint(0, 0.1), new NumberSequenceKeypoint(1, 1)]);
			dust.Lifetime = new NumberRange(0.5, 1.1);
			dust.Speed = new NumberRange(2, 7);
			dust.SpreadAngle = new Vector2(180, 180);
			dust.Acceleration = new Vector3(0, 7, 0);
			dust.Drag = 2;
			dust.Rate = 140;
			dust.Shape = Enum.ParticleEmitterShape.Box;
			dust.Parent = torso;
			this.fx.push(dust);
			this.onEmitter?.(dust);
		}
		for (const [d, t0] of this.fading) d.Transparency = t0 + (1 - t0) * a;
		if (this.highlight) this.highlight.OutlineTransparency = math.max(this.highlight.OutlineTransparency, a);
		if (a >= 1) this.setVisible(false);
	}

	private updateJoints(now: number, dt: number) {
		if (this.animTracks > 0) return;
		// Lapisan hidup: makin cepat badan gerak, makin kecil (biar gak ganggu tebasan)
		const amp = this.still ? 0 : 1 / (1 + this.energy * 0.006);
		const t = now + this.seed;
		const breath = math.sin(t * 1.9);
		const n = (f: number, k: number) => math.noise(t * f, k, this.seed) * 2;

		// Lari: fase langkah ikut jarak tempuh di tanah
		const height = this.origin.PointToObjectSpace(this.feet.Position).Y;
		const grounded = !this.knocked && height < 1.5;
		const flatSpeed = new Vector3(this.velS.X, 0, this.velS.Z).Magnitude;
		const dash = math.clamp((flatSpeed - 22) / 14, 0, 1);
		const run = grounded ? math.clamp((flatSpeed - 2) / 7, 0, 1) * (1 - dash) : 0;
		this.phase += ((math.min(flatSpeed, 20) * dt) / 5.5) * math.pi * 2;
		const ph = this.phase;
		const sp = math.sin(ph);
		const cp = math.cos(ph);
		const armSwing = this.poseArms ? 0.2 : 1;

		// Condong ke arah gerak / percepatan (sumbu badan sendiri)
		const lv = this.feet.VectorToObjectSpace(this.velS);
		const la = this.feet.VectorToObjectSpace(this.accS);
		const lean = this.knocked ? 0 : math.clamp(-lv.Z * 0.5 + -la.Z * 0.03, -16, 22);
		const roll = this.knocked ? 0 : math.clamp(lv.X * 0.25 + la.X * 0.03, -14, 14);

		// Siaga mantul / melayang di udara
		const alert = !this.still && ALERT.has(this.poseName) ? 1 : 0;
		const bounce = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 1.15);
		const airborne = !this.still && !this.knocked && height > 1.5 && flatSpeed < 6 ? 1 : 0;
		const hover = math.sin(t * 1.6);

		let energy = 0;
		for (const j of this.joints) {
			for (let i = 0; i < 4; i++) {
				if (dt > 0) springStep(j.x, j.v, j.to, i, j.w, j.z, dt);
			}
			energy += math.abs(j.v[0]) + math.abs(j.v[1]) + math.abs(j.v[2]);
			let rx = j.x[0];
			let ry = j.x[1];
			let rz = j.x[2];
			let dy = j.x[3];
			switch (j.name) {
				case "Root":
					rx += -lean - 10 * dash + n(0.3, 1.1) * 0.8 * amp;
					ry += n(0.25, 2.3) * 1.5 * amp;
					rz += -roll + n(0.3, 3.7) * 0.8 * amp;
					dy += -0.13 * run * math.abs(cp) - 0.05 * alert * bounce + 0.14 * airborne * hover;
					break;
				case "Waist":
					rx += breath * 1.3 * amp - 4 * run;
					ry += n(0.3, 4.1) * 2 * amp + sp * 9 * run;
					break;
				case "Neck":
					rx += -breath * 0.6 * amp + n(0.35, 5.3) * 2.5 * amp + 6 * dash;
					ry += n(0.22, 6.7) * 4 * amp;
					break;
				case "RightShoulder":
					rx += n(0.4, 7.9) * 2 * amp - sp * 32 * run * armSwing;
					rz += breath * 0.9 * amp;
					break;
				case "LeftShoulder":
					rx += n(0.4, 8.3) * 2 * amp + sp * 32 * run * armSwing;
					rz -= breath * 0.9 * amp;
					break;
				case "RightElbow":
				case "LeftElbow":
					rx += 22 * run * armSwing;
					break;
				case "RightWrist":
					rx += n(0.5, 9.7) * 3 * amp;
					break;
				case "RightHip":
					rx += sp * 40 * run - 28 * dash - 4 * alert * bounce + 6 * airborne * hover;
					break;
				case "LeftHip":
					rx += -sp * 40 * run - 18 * dash - 4 * alert * bounce - 4 * airborne * hover;
					break;
				case "RightKnee":
					rx += -(8 + 58 * math.max(0, cp)) * run - 35 * dash - 5 * alert * bounce - 6 * airborne * hover;
					break;
				case "LeftKnee":
					rx += -(8 + 58 * math.max(0, -cp)) * run - 25 * dash - 5 * alert * bounce + 4 * airborne * hover;
					break;
			}
			const rot = jointCFrame(rx, ry, rz, dy);
			if (j.motor) j.motor.C0 = j.c0.mul(rot);
			else if (j.ac) j.ac.Transform = rot;
		}
		this.energy = energy;
	}

	private updateSway(now: number, dt: number) {
		if (dt <= 0) return;
		for (const s of this.sways) {
			const pos = s.part.Position;
			const vel = pos.sub(s.lastPos).div(dt);
			const acc = vel.sub(s.lastVel).div(dt);
			s.lastPos = pos;
			s.lastVel = vel;
			// Percepatan di sumbu bagian badan itu sendiri + gravitasi (biar ujungnya selalu "jatuh" ke bawah)
			const rel = s.part.CFrame.VectorToObjectSpace(acc.add(new Vector3(0, GRAVITY * 0.3, 0)));
			s.to[0] = math.clamp(rel.Z * s.k, -s.max, s.max);
			s.to[1] = math.clamp(-rel.X * s.k, -s.max, s.max);
			springStep(s.x, s.v, s.to, 0, 7, 0.32, dt);
			springStep(s.x, s.v, s.to, 1, 7, 0.32, dt);
			const f = this.still ? 0 : s.flutter * math.noise(now * 1.7, this.seed, s.k * 10);
			s.apply(math.clamp(s.x[0] + f, -s.max, s.max), math.clamp(s.x[1] + f * 0.6, -s.max, s.max));
		}
	}

	destroy() {
		this.model.Destroy();
	}
}
