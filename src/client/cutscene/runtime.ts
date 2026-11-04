// Pemutar satu cutscene: jam timeline (slow-mo + hitstop), kamera spline, aktor, event, VFX, UI, suara.
// Satu RenderStep per cutscene, semua instance dibikin lokal dan dihapus pas selesai atau di-skip.

import { Players, RunService, SoundService, StarterGui, TweenService, Workspace } from "@rbxts/services";
import { MUSIC, SFX } from "shared/cutscene/audio";
import { ease } from "shared/cutscene/ease";
import { CamKey, CutEvent, CutsceneDef } from "shared/cutscene/types";
import { Actor } from "./actors";
import { Post } from "./post";
import { detectQuality, Quality } from "./quality";
import { Tweens } from "./tweens";
import { CutsceneUI } from "./ui";
import * as vfx from "./vfx";

const RENDER_NAME = "CutsceneCamera";
const CORE_TYPES = [
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.EmotesMenu,
];
const WHITE = new Color3(1, 1, 1);

interface Controls {
	Enable(): void;
	Disable(): void;
}

function playerControls(): Controls | undefined {
	const module = Players.LocalPlayer.FindFirstChild("PlayerScripts")?.FindFirstChild("PlayerModule");
	if (!module || !module.IsA("ModuleScript")) return undefined;
	const [ok, controls] = pcall(() => (require(module) as { GetControls(): Controls }).GetControls());
	return ok ? controls : undefined;
}

function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number) {
	const t2 = t * t;
	const t3 = t2 * t;
	return p1
		.mul(2)
		.add(p2.sub(p0).mul(t))
		.add(p0.mul(2).sub(p1.mul(5)).add(p2.mul(4)).sub(p3).mul(t2))
		.add(p1.mul(3).sub(p0).sub(p2.mul(3)).add(p3).mul(t3))
		.mul(0.5);
}

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Urut berdasarkan t, yang t-nya sama tetap urutan aslinya (table.sort Lua gak stabil). */
function byTime<T extends { t: number }>(list: readonly T[]): T[] {
	const indexed = list.map((item, i) => ({ item, i }));
	indexed.sort((a, b) => a.item.t < b.item.t || (a.item.t === b.item.t && a.i < b.i));
	return indexed.map((x) => x.item);
}

export class CutsceneRun {
	private q: Quality;
	private tw = new Tweens();
	private origin: CFrame;
	private root: Folder;
	private actors = new Map<string, Actor>();
	private keys: CamKey[];
	private events: CutEvent[];
	private nextEvent = 0;
	private camIdx = 0;
	private now = 0;
	private rate = 1;
	private hitstopUntil = 0;
	private shakes = new Array<{ t0: number; dur: number; mag: number }>();
	private ctx: vfx.VfxCtx;
	private ui: CutsceneUI;
	private post?: Post;
	private music?: Sound;
	private sounds = new Array<Sound>();
	private hiddenGuis = new Array<ScreenGui>();
	private coreState = new Array<[Enum.CoreGuiType, boolean]>();
	private controls?: Controls;
	private savedFov = 70;
	private ended = false;
	private started = false;

	constructor(private def: CutsceneDef, private onDone: (skipped: boolean) => void) {
		this.q = detectQuality();
		const anchor = def.anchor !== undefined ? Workspace.FindFirstChild("CutsceneAnchors")?.FindFirstChild(def.anchor) : undefined;
		this.origin = anchor && anchor.IsA("BasePart") ? anchor.CFrame : def.origin;
		this.keys = byTime(def.camera);
		this.events = byTime(def.events);
		this.root = new Instance("Folder");
		this.root.Name = `Cutscene_${def.id}`;
		this.ctx = { root: this.root, tw: this.tw, origin: this.origin, q: this.q, rate: 1, emitters: [] };
		this.ui = new CutsceneUI(this.q, this.tw, () => this.finish(true));
	}

	start() {
		if (this.started) return;
		this.started = true;
		const def = this.def;
		const player = Players.LocalPlayer;

		// Sembunyiin HUD game dan CoreGui, kunci kontrol
		for (const gui of player.WaitForChild("PlayerGui").GetChildren()) {
			if (gui.IsA("ScreenGui") && gui.Enabled && gui.Name !== "CutsceneUI") {
				gui.Enabled = false;
				this.hiddenGuis.push(gui);
			}
		}
		for (const t of CORE_TYPES) {
			const [ok, on] = pcall(() => StarterGui.GetCoreGuiEnabled(t));
			if (ok) this.coreState.push([t, on]);
		}
		pcall(() => StarterGui.SetCoreGuiEnabled(Enum.CoreGuiType.All, false));
		this.controls = playerControls();
		this.controls?.Disable();

		// Set dan aktor
		def.build?.(this.root, this.q.low);
		this.root.Parent = Workspace;
		for (const a of def.actors) {
			const actor = Actor.create(a, this.root, this.origin);
			if (actor) this.actors.set(a.id, actor);
		}

		this.post = new Post(def.look, this.q.dof);
		const cam = Workspace.CurrentCamera!;
		this.savedFov = cam.FieldOfView;
		cam.CameraType = Enum.CameraType.Scriptable;
		this.ui.letterbox(true);

		let last = os.clock();
		RunService.BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, () => {
			const clock = os.clock();
			const dt = math.min(clock - last, 0.1);
			last = clock;
			this.step(dt, clock);
		});
	}

	private step(dt: number, clock: number) {
		if (this.ended) return;
		const rate = clock < this.hitstopUntil ? 0.02 : this.rate;
		if (rate !== this.ctx.rate) this.setParticleRate(rate);
		this.now += dt * rate;
		const now = this.now;

		while (this.nextEvent < this.events.size() && this.events[this.nextEvent].t <= now) {
			this.fire(this.events[this.nextEvent]);
			this.nextEvent += 1;
		}

		this.tw.update(now);
		const breathe = math.sin(now * 1.8);
		for (const [, actor] of this.actors) {
			actor.update(now, breathe);
			if (actor.ghosting && actor.visible && this.q.ghosts > 0 && actor.liveGhosts < this.q.ghosts && now - actor.lastGhost >= 0.05) {
				actor.lastGhost = now;
				vfx.ghost(this.ctx, actor);
			}
		}
		this.updateCamera(now, clock);
		this.post?.update();
		this.ui.update(dt);

		if (now >= this.def.length) this.finish(false);
	}

	private setParticleRate(rate: number) {
		this.ctx.rate = rate;
		const alive = this.ctx.emitters.filter((e) => e.Parent !== undefined);
		for (const e of alive) e.TimeScale = rate;
		this.ctx.emitters = alive;
	}

	private keyPos(k: CamKey) {
		const a = k.follow !== undefined ? this.actors.get(k.follow) : undefined;
		return a ? a.root.Position.add(this.origin.VectorToWorldSpace(k.pos)) : this.origin.PointToWorldSpace(k.pos);
	}

	private keyLook(k: CamKey) {
		const a = k.track !== undefined ? this.actors.get(k.track) : undefined;
		return a ? a.root.Position.add(this.origin.VectorToWorldSpace(k.look)) : this.origin.PointToWorldSpace(k.look);
	}

	private updateCamera(now: number, clock: number) {
		const keys = this.keys;
		if (keys.size() === 0) return;
		while (this.camIdx + 1 < keys.size() && keys[this.camIdx + 1].t <= now) this.camIdx += 1;
		const i = this.camIdx;
		const k1 = keys[i];
		const k2 = keys[i + 1];
		let pos: Vector3;
		let look: Vector3;
		let fov = k1.fov ?? 70;
		let roll = k1.roll ?? 0;
		let dof = k1.dof ?? 0;
		if (k2 === undefined || k2.cut || now < k1.t) {
			pos = this.keyPos(k1);
			look = this.keyLook(k1);
		} else {
			const e = ease(k2.ease, (now - k1.t) / math.max(k2.t - k1.t, 1e-3));
			const p1 = this.keyPos(k1);
			const p2 = this.keyPos(k2);
			const k0 = keys[i - 1];
			const k3 = keys[i + 2];
			const p0 = k0 !== undefined && !k1.cut ? this.keyPos(k0) : p1;
			const p3 = k3 !== undefined && !k3.cut ? this.keyPos(k3) : p2;
			pos = catmull(p0, p1, p2, p3, e);
			look = this.keyLook(k1).Lerp(this.keyLook(k2), e);
			fov = lerp(fov, k2.fov ?? fov, e);
			roll = lerp(roll, k2.roll ?? 0, e);
			dof = lerp(dof, k2.dof ?? 0, e);
		}

		// Goyang tangan (pelan, terus-terusan) + guncangan impact (cepat, meluruh). Pakai waktu asli
		const hand = this.def.look?.handheld ?? 0;
		let rx = math.noise(clock * 0.35, 1.3) * 2 * hand;
		let ry = math.noise(clock * 0.3, 7.1) * 2 * hand;
		let rz = 0;
		for (let s = this.shakes.size() - 1; s >= 0; s--) {
			const sh = this.shakes[s];
			const a = (clock - sh.t0) / sh.dur;
			if (a >= 1) {
				this.shakes.unorderedRemove(s);
				continue;
			}
			const amp = sh.mag * (1 - a) ** 2;
			rx += math.noise(clock * 22, 3.7) * 4 * amp;
			ry += math.noise(clock * 22, 9.2) * 4 * amp;
			rz += math.noise(clock * 18, 5.5) * 2 * amp;
		}

		const cam = Workspace.CurrentCamera!;
		cam.CFrame = CFrame.lookAt(pos, look).mul(CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(roll + rz)));
		cam.FieldOfView = fov;
		cam.Focus = new CFrame(look);
		this.post?.focus(look.sub(pos).Magnitude, dof);
	}

	private sound(id: string, volume: number, looped: boolean) {
		const s = new Instance("Sound");
		s.SoundId = id;
		s.Volume = volume;
		s.Looped = looped;
		s.Parent = SoundService;
		s.Play();
		this.sounds.push(s);
		if (!looped) s.Ended.Once(() => s.Destroy());
		return s;
	}

	private fire(e: CutEvent) {
		const now = this.now;
		switch (e.kind) {
			case "sub":
				this.ui.subtitle(e.who, e.text, e.dur);
				break;
			case "card":
				this.ui.nameCard(e.name, e.cn, e.epithet, e.dur);
				break;
			case "title":
				this.ui.showTitle(e.text, e.sub, e.dur);
				break;
			case "fade":
				this.ui.fade(e.to, e.dur, e.color ?? new Color3(0, 0, 0));
				break;
			case "shake":
				this.shakes.push({ t0: os.clock(), dur: e.dur, mag: e.mag });
				break;
			case "impact": {
				const s = e.strength ?? 1;
				this.hitstopUntil = os.clock() + 0.06 + 0.05 * s;
				this.post?.impactFrame(s);
				this.ui.speedLines(0.25 + 0.1 * s);
				this.shakes.push({ t0: os.clock(), dur: 0.35 + 0.1 * s, mag: 0.5 * s });
				const id = SFX.impact;
				if (id !== "") this.sound(id, 0.8, false);
				break;
			}
			case "speed":
				this.rate = math.max(e.scale, 0.01);
				break;
			case "lines":
				this.ui.speedLines(e.dur);
				break;
			case "move":
				this.actors.get(e.actor)?.moveTo(this.origin.mul(e.to), e.dur, e.ease, now, e.ghost === true);
				break;
			case "pose":
				this.actors.get(e.actor)?.setPose(e.pose, e.dur, e.ease, now);
				break;
			case "anim":
				this.actors.get(e.actor)?.playAnim(e.animId, e.speed ?? 1);
				break;
			case "show":
				this.actors.get(e.actor)?.setVisible(true);
				break;
			case "hide":
				this.actors.get(e.actor)?.setVisible(false);
				break;
			case "break": {
				const tip = this.actors.get(e.actor)?.breakBlade();
				if (tip) {
					const rel = this.origin.PointToObjectSpace(tip);
					vfx.debris(this.ctx, rel, 0.5, Color3.fromRGB(215, 220, 228), 10);
					vfx.burst(this.ctx, rel, Color3.fromRGB(190, 225, 255), 1);
				}
				break;
			}
			case "vfx":
				this.fireVfx(e);
				break;
			case "sfx": {
				const id = SFX[e.name] ?? "";
				if (id !== "") this.sound(id, e.volume ?? 0.8, false);
				break;
			}
			case "music": {
				const id = MUSIC[e.name] ?? "";
				const fade = e.fade ?? 1.5;
				const old = this.music;
				if (old) {
					TweenService.Create(old, new TweenInfo(fade), { Volume: 0 }).Play();
					task.delay(fade, () => old.Destroy());
				}
				this.music = undefined;
				if (id !== "") {
					const s = this.sound(id, 0, true);
					TweenService.Create(s, new TweenInfo(fade), { Volume: e.volume ?? 0.5 }).Play();
					this.music = s;
				}
				break;
			}
		}
	}

	private fireVfx(e: Extract<CutEvent, { kind: "vfx" }>) {
		const color = e.color ?? WHITE;
		switch (e.name) {
			case "slash":
				vfx.slash(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1, e.dur ?? 0.45);
				break;
			case "burst":
				vfx.burst(this.ctx, e.at, color, e.scale ?? 1);
				break;
			case "ring":
				vfx.ring(this.ctx, e.at, e.scale ?? 20, color, e.normal);
				break;
			case "fall":
				vfx.fall(this.ctx, e.at, e.via ?? e.at.Lerp(e.to ?? e.at, 0.5), e.to ?? e.at, e.dur ?? 3, color);
				break;
			case "debris":
				vfx.debris(this.ctx, e.at, e.scale ?? 1, e.color);
				break;
			case "collapse":
				if (e.target !== undefined) vfx.collapse(this.ctx, e.target, e.at, e.dur);
				break;
		}
	}

	/** Selesai normal atau di-skip. Aman dipanggil berkali-kali. */
	finish(skipped: boolean) {
		if (this.ended) return;
		this.ended = true;
		if (!this.started) {
			this.ui.destroy();
			this.onDone(skipped);
			return;
		}
		this.ui.hideSkip();
		// Gelapin dulu biar gak kelihatan set ilang
		this.ui.fadeReal(1, 0.3);
		task.delay(0.3, () => this.close(skipped));
	}

	private close(skipped: boolean) {
		RunService.UnbindFromRenderStep(RENDER_NAME);
		this.tw.clear();
		for (const [, actor] of this.actors) actor.destroy();
		this.actors.clear();
		this.root.Destroy();
		this.post?.destroy();
		for (const s of this.sounds) s.Destroy();
		this.sounds.clear();

		const cam = Workspace.CurrentCamera!;
		const hum = Players.LocalPlayer.Character?.FindFirstChildOfClass("Humanoid");
		cam.CameraType = Enum.CameraType.Custom;
		if (hum) cam.CameraSubject = hum;
		cam.FieldOfView = this.savedFov;

		for (const gui of this.hiddenGuis) gui.Enabled = true;
		this.hiddenGuis.clear();
		for (const [t, on] of this.coreState) pcall(() => StarterGui.SetCoreGuiEnabled(t, on));
		this.controls?.Enable();

		// Balik ke game dari layar gelap
		this.ui.letterbox(false, 0.5);
		this.ui.fadeReal(0, 0.8);
		const ui = this.ui;
		task.delay(0.9, () => ui.destroy());
		this.onDone(skipped);
	}
}
