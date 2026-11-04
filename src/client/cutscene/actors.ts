// Aktor cutscene: salinan rig R15 yang digerakin lewat HumanoidRootPart (anchored) dan C0 Motor6D.
// Gak butuh animasi yang di-upload, jadi langsung jalan di game asli. Semua lokal di client.

import { Players, ReplicatedStorage } from "@rbxts/services";
import { ease } from "shared/cutscene/ease";
import { jointCFrame, POSES } from "shared/cutscene/poses";
import { ActorDef, Ease } from "shared/cutscene/types";

const ID = new CFrame();
const STRIKES = new Set(["slashFollow", "thrust"]);
const QI = Color3.fromRGB(190, 225, 255);

interface Joint {
	motor: Motor6D;
	c0: CFrame;
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

	private parent: Instance;
	private lift: CFrame;
	private feet: CFrame;
	private joints = new Map<string, Joint>();
	private cur = new Map<string, CFrame>();
	private from = new Map<string, CFrame>();
	private target = new Map<string, CFrame>();
	private poseT0 = 0;
	private poseDur = 1e-3;
	private poseEase?: Ease;
	private settled = true;

	private moving = false;
	private mFrom = ID;
	private mTo = ID;
	private mT0 = 0;
	private mDur = 1e-3;
	private mEase?: Ease;

	private blade?: BasePart;
	private bladeWeld?: Weld;
	private edge?: BasePart;
	private edgeWeld?: Weld;
	private trail?: Trail;
	private trailOff = 0;
	private animator?: Animator;
	private ghostParts: BasePart[] = [];

	static create(def: ActorDef, parent: Instance, origin: CFrame): Actor | undefined {
		const [model, needsPaint] = source(def);
		if (!model) return undefined;
		return new Actor(def, model, needsPaint, parent, origin);
	}

	private constructor(def: ActorDef, model: Model, needsPaint: boolean, parent: Instance, origin: CFrame) {
		this.model = model;
		this.parent = parent;
		this.ghostColor = def.ghostColor ?? QI;
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
			this.animator = hum.FindFirstChildOfClass("Animator");
			if (this.animator) for (const track of this.animator.GetPlayingAnimationTracks()) track.Stop(0);
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
				if (d !== root && d.Transparency < 0.99) this.ghostParts.push(d);
			} else if (d.IsA("Motor6D")) {
				this.joints.set(d.Name, { motor: d, c0: d.C0 });
				d.Transform = ID;
			}
		}
		const liftY = hum ? root.Size.Y / 2 + hum.HipHeight : 3;
		this.lift = new CFrame(0, liftY, 0);
		this.feet = origin.mul(def.start);
		root.CFrame = this.feet.mul(this.lift);

		if (def.weapon === "jian") this.attachJian();
		model.Parent = parent;
		if (def.hidden) this.setVisible(false);
	}

	/** Pedang greybox di tangan kanan, dengan trail buat jejak tebasan. */
	private attachJian() {
		const hand = (this.model.FindFirstChild("RightHand") ?? this.model.FindFirstChild("Right Arm")) as BasePart | undefined;
		if (!hand) return;
		const grip = new CFrame(0, -0.25, 0);
		const make = (name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): [Part, Weld] => {
			const p = new Instance("Part");
			p.Name = name;
			p.Size = size;
			p.Color = color;
			p.Material = material;
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
			return [p, w];
		};
		make("Grip", new Vector3(0.22, 0.22, 1), new CFrame(0, 0, 0.1), Color3.fromRGB(60, 40, 30), Enum.Material.Wood);
		make("Guard", new Vector3(0.18, 0.85, 0.2), new CFrame(0, 0, -0.5), Color3.fromRGB(200, 165, 90), Enum.Material.Metal);
		const [blade, bladeWeld] = make("Blade", new Vector3(0.08, 0.3, 4.4), new CFrame(0, 0, -2.8), Color3.fromRGB(215, 220, 228), Enum.Material.Metal);
		const [edge, edgeWeld] = make("Edge", new Vector3(0.04, 0.06, 4.3), new CFrame(0, 0.15, -2.8), QI, Enum.Material.Neon);
		edge.Transparency = 0.3;
		blade.Reflectance = 0.2;

		const a0 = new Instance("Attachment");
		a0.Position = new Vector3(0, 0, 2);
		a0.Parent = blade;
		const a1 = new Instance("Attachment");
		a1.Position = new Vector3(0, 0, -2.2);
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
	}

	setPose(name: string, dur: number, e: Ease | undefined, now: number) {
		const pose = POSES[name] ?? {};
		for (const [n] of this.joints) {
			this.from.set(n, this.cur.get(n) ?? ID);
			this.target.set(n, jointCFrame(pose[n]));
		}
		this.poseT0 = now;
		this.poseDur = math.max(dur, 1e-3);
		this.poseEase = e;
		this.settled = false;
		if (this.trail && STRIKES.has(name)) {
			this.trail.Enabled = true;
			this.trailOff = now + dur + 0.25;
		}
	}

	moveTo(feet: CFrame, dur: number, e: Ease | undefined, now: number, ghost: boolean) {
		this.mFrom = this.feet;
		this.mTo = feet;
		this.mT0 = now;
		this.mDur = math.max(dur, 1e-3);
		this.mEase = e;
		this.moving = true;
		this.ghosting = ghost;
	}

	playAnim(id: string, speed: number) {
		if (!this.animator) return;
		const anim = new Instance("Animation");
		anim.AnimationId = id;
		const track = this.animator.LoadAnimation(anim);
		track.Play(0.1, 1, speed);
	}

	/** Patahin pedang. Balikin posisi ujung lama (buat serpihan). */
	breakBlade(): Vector3 | undefined {
		const blade = this.blade;
		if (!blade || !this.bladeWeld) return undefined;
		const tip = blade.CFrame.PointToWorldSpace(new Vector3(0, 0, -blade.Size.Z / 2));
		const len = blade.Size.Z * 0.35;
		const grip = new CFrame(0, -0.25, 0);
		blade.Size = new Vector3(blade.Size.X, blade.Size.Y, len);
		this.bladeWeld.C0 = grip.mul(new CFrame(0, 0, -0.6 - len / 2));
		if (this.edge && this.edgeWeld) {
			this.edge.Size = new Vector3(this.edge.Size.X, this.edge.Size.Y, len);
			this.edgeWeld.C0 = grip.mul(new CFrame(0, 0.15, -0.6 - len / 2));
		}
		if (this.trail) this.trail.Enabled = false;
		this.trail = undefined;
		return tip;
	}

	setVisible(v: boolean) {
		this.visible = v;
		this.model.Parent = v ? this.parent : undefined;
	}

	/** Bagian badan yang kelihatan, buat bikin bayangan (afterimage). */
	parts(): readonly BasePart[] {
		return this.ghostParts;
	}

	update(now: number, breathe: number) {
		if (!this.visible) return;
		if (this.moving) {
			const a = (now - this.mT0) / this.mDur;
			this.feet = this.mFrom.Lerp(this.mTo, ease(this.mEase, a));
			this.root.CFrame = this.feet.mul(this.lift);
			if (a >= 1) {
				this.moving = false;
				this.ghosting = false;
			}
		}
		if (this.trail && this.trail.Enabled && now > this.trailOff) this.trail.Enabled = false;

		// Pose: kalau udah sampai, cuma napas (Waist + Neck) yang di-update biar hemat
		const a = ease(this.poseEase, (now - this.poseT0) / this.poseDur);
		for (const [n, j] of this.joints) {
			const breathing = n === "Waist" || n === "Neck";
			if (this.settled && !breathing) continue;
			let c = this.cur.get(n) ?? ID;
			if (!this.settled) {
				c = (this.from.get(n) ?? ID).Lerp(this.target.get(n) ?? ID, a);
				this.cur.set(n, c);
			}
			const extra = n === "Waist" ? CFrame.Angles(breathe * 0.03, 0, 0) : n === "Neck" ? CFrame.Angles(-breathe * 0.015, 0, 0) : ID;
			j.motor.C0 = j.c0.mul(c).mul(extra);
		}
		if (!this.settled && now - this.poseT0 >= this.poseDur) this.settled = true;
	}

	destroy() {
		this.model.Destroy();
	}
}
