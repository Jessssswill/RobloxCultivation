// Pemutar satu cutscene: jam timeline (slow-mo + hitstop), kamera spline, aktor, event, VFX, UI, suara.
// Satu RenderStep per cutscene, semua instance dibikin lokal dan dihapus pas selesai atau di-skip.
// Suara Mandarin pakai AudioTextToSpeech Roblox (gak perlu upload), dimuat satu-satu di belakang layar.

import { ContentProvider, Players, ReplicatedStorage, RunService, SoundService, StarterGui, TweenService, Workspace } from "@rbxts/services";
import { MUSIC, SFX, VOICES } from "shared/cutscene/audio";
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
const QI = Color3.fromRGB(190, 225, 255);
/** Maksimal nunggu rig + aset kebuka sebelum mulai (layar hitam). */
const LOAD_WAIT = 4;

type SubEvent = Extract<CutEvent, { kind: "sub" }>;
type VoiceEvent = Extract<CutEvent, { kind: "voice" }>;

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

/** Set properti satu-satu pakai pcall: API Audio masih baru, nama properti bisa berubah. */
function setProps(inst: Instance, props: Record<string, unknown>) {
	for (const [k, v] of pairs(props)) pcall(() => ((inst as unknown as Record<string, unknown>)[k] = v));
}

function wire(from: Instance, to: Instance) {
	const w = new Instance("Wire");
	w.SourceInstance = from;
	w.TargetInstance = to;
	w.Parent = to;
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
	private musicVol = 0.5;
	private duckToken = 0;
	private sounds = new Array<Sound>();
	/** SFX loop yang lagi jalan, per nama (biar volumenya bisa diatur event berikutnya). */
	private loops = new Map<string, Sound>();
	private voiceFolder?: Folder;
	private voiceLines = new Map<CutEvent, AudioTextToSpeech>();
	private hiddenGuis = new Array<ScreenGui>();
	private coreState = new Array<[Enum.CoreGuiType, boolean]>();
	private controls?: Controls;
	private savedFov = 70;
	private ended = false;
	private started = false;
	private bound = false;
	private beganAt = 0;
	private slowTime = 0;
	private degraded = false;
	private propVals = new Map<string, number>();
	private setEmitters = new Set<ParticleEmitter>();
	private frozen = false;

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
		const player = Players.LocalPlayer;

		// Layar hitam dulu selama rig, suara, dan tekstur dimuat
		this.ui.fadeReal(1, 0.25);
		this.savedFov = Workspace.CurrentCamera!.FieldOfView;

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

		this.loadVoices();
		task.spawn(() => {
			this.waitForAssets();
			if (!this.ended) this.begin();
		});
	}

	/** Tunggu rig dari server + preload tekstur/suara, maksimal LOAD_WAIT detik. */
	private waitForAssets() {
		const t0 = os.clock();
		const rigs = ReplicatedStorage.WaitForChild("CutsceneRigs", LOAD_WAIT);
		const needed = new Set<string>();
		for (const a of this.def.actors) {
			if (a.look === "template" && a.template !== undefined) needed.add(a.template);
			if (a.sword !== undefined) needed.add(a.sword);
		}
		while (os.clock() - t0 < LOAD_WAIT) {
			let missing = false;
			for (const name of needed) if (!rigs?.FindFirstChild(name)) missing = true;
			if (!missing) break;
			task.wait(0.2);
		}
		const content = new Array<Instance | string>();
		for (const name of needed) {
			const rig = rigs?.FindFirstChild(name);
			if (rig) content.push(rig);
		}
		for (const e of this.events) {
			if (e.kind === "music" && (MUSIC[e.name] ?? "") !== "") content.push(MUSIC[e.name]);
			if (e.kind === "sfx" && (SFX[e.name] ?? "") !== "") content.push(SFX[e.name]);
		}
		let done = false;
		task.spawn(() => {
			pcall(() => ContentProvider.PreloadAsync(content as Instance[]));
			done = true;
		});
		while (!done && os.clock() - t0 < LOAD_WAIT) task.wait(0.1);
	}

	private begin() {
		const def = this.def;
		def.build?.(this.root, this.q.tier);
		this.root.Parent = Workspace;
		// Emitter set (debu, partikel qi melayang) ikut slow-mo juga
		for (const d of this.root.GetDescendants()) {
			if (!d.IsA("ParticleEmitter")) continue;
			this.ctx.emitters.push(d);
			this.setEmitters.add(d);
		}
		if (def.props) {
			for (const [name, p] of pairs(def.props)) {
				this.propVals.set(name, p.init);
				p.set(this.root, p.init);
			}
		}
		for (const a of def.actors) {
			const actor = Actor.create(a, this.root, this.origin, this.q);
			if (!actor) continue;
			this.actors.set(a.id, actor);
			for (const e of actor.fx) this.ctx.emitters.push(e);
			actor.onEmitter = (e) => {
				e.TimeScale = this.ctx.rate;
				this.ctx.emitters.push(e);
			};
		}

		this.post = new Post(def.look, this.q.dof);
		Workspace.CurrentCamera!.CameraType = Enum.CameraType.Scriptable;
		this.ui.letterbox(true);

		let last = os.clock();
		this.beganAt = last;
		this.bound = true;
		RunService.BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, () => {
			const clock = os.clock();
			const dt = math.min(clock - last, 0.1);
			last = clock;
			this.step(dt, clock);
		});
	}

	/** Bikin rantai suara per profil (pitch, echo, reverb, volume) lalu muat kalimat Mandarin satu-satu. */
	private loadVoices() {
		const lines = this.events.filter(
			(e): e is SubEvent | VoiceEvent => (e.kind === "sub" && e.zh !== undefined && e.voice !== undefined) || e.kind === "voice",
		);
		if (lines.size() === 0) return;
		const folder = new Instance("Folder");
		folder.Name = "CutsceneVoice";
		folder.Parent = SoundService;
		this.voiceFolder = folder;
		const out = new Instance("AudioDeviceOutput");
		out.Parent = folder;
		const chains = new Map<string, Instance>();
		const chainFor = (name: string) => {
			const existing = chains.get(name);
			if (existing) return existing;
			const v = VOICES[name];
			const pitch = new Instance("AudioPitchShifter");
			setProps(pitch, { Pitch: v.pitch });
			pitch.Parent = folder;
			let tail: Instance = pitch;
			if (v.echo !== undefined && v.echo > 0) {
				const echo = new Instance("AudioEcho");
				setProps(echo, { DelayTime: 0.28, Feedback: 0.25, WetLevel: -18 + 12 * v.echo, DryLevel: 0 });
				echo.Parent = folder;
				wire(tail, echo);
				tail = echo;
			}
			if (v.reverb > 0) {
				const reverb = new Instance("AudioReverb");
				setProps(reverb, { DecayTime: 1 + 2.5 * v.reverb, WetLevel: -16 + 12 * v.reverb, DryLevel: 0, Density: 1, Diffusion: 1 });
				reverb.Parent = folder;
				wire(tail, reverb);
				tail = reverb;
			}
			const fader = new Instance("AudioFader");
			setProps(fader, { Volume: v.volume });
			fader.Parent = folder;
			wire(tail, fader);
			wire(fader, out);
			chains.set(name, pitch);
			return pitch;
		};
		task.spawn(() => {
			// Satu-satu: TTS Roblox gagal kalau dimuat barengan (dicek 4 Nov)
			for (const e of lines) {
				if (this.ended) return;
				const zh = e.zh;
				const name = e.voice;
				if (zh === undefined || name === undefined || VOICES[name] === undefined) continue;
				const v = VOICES[name];
				const tts = new Instance("AudioTextToSpeech");
				tts.AutoLocalize = false;
				tts.VoiceId = v.voiceId;
				tts.Speed = v.speed;
				tts.Text = zh;
				tts.Parent = folder;
				wire(tts, chainFor(name));
				let ok = false;
				for (let attempt = 0; attempt < 2 && !ok && !this.ended; attempt++) {
					const [success, status] = pcall(() => tts.LoadAsync());
					ok = success && status === Enum.AssetFetchStatus.Success;
					if (!ok) task.wait(1);
				}
				if (ok) this.voiceLines.set(e, tts);
				else tts.Destroy();
			}
		});
	}

	/** Putar suara kalimat ini kalau udah kemuat. Balikin durasinya (0 kalau gak ada). */
	private speak(e: CutEvent) {
		const tts = this.voiceLines.get(e);
		if (!tts) return 0;
		tts.TimePosition = 0;
		tts.Play();
		this.duck(tts.TimeLength + 0.3);
		return tts.TimeLength;
	}

	/** Kecilin musik selama ada yang ngomong (biar suara gak tabrakan sama lagu). */
	private duck(seconds: number) {
		const m = this.music;
		if (!m || m.Parent === undefined) return;
		this.duckToken += 1;
		const token = this.duckToken;
		TweenService.Create(m, new TweenInfo(0.25), { Volume: this.musicVol * 0.35 }).Play();
		task.delay(seconds, () => {
			if (token === this.duckToken && this.music === m) TweenService.Create(m, new TweenInfo(0.8), { Volume: this.musicVol }).Play();
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
		for (const [, actor] of this.actors) {
			actor.update(now);
			if (actor.ghosting && actor.visible && this.q.ghosts > 0 && actor.liveGhosts < this.q.ghosts && now - actor.lastGhost >= 0.05) {
				actor.lastGhost = now;
				vfx.ghost(this.ctx, actor);
			}
		}
		this.updateCamera(now, clock);
		this.post?.update();
		this.ui.update(dt);
		this.guardFps(dt, clock);

		if (now >= this.def.length) this.finish(false);
	}

	/** Pengaman: kalau FPS di bawah ~25 terus-terusan, turunin efek sekali (partikel, bayangan, DOF). */
	private guardFps(dt: number, clock: number) {
		if (this.degraded || this.q.tier === 0 || clock - this.beganAt < 2) return;
		this.slowTime = math.max(0, this.slowTime + (dt > 1 / 25 ? dt : -dt * 0.5));
		if (this.slowTime < 1.5) return;
		this.degraded = true;
		this.q.particles *= 0.5;
		this.q.ghosts = math.min(this.q.ghosts, 3);
		this.q.dof = false;
		this.post?.disableDof();
		for (const e of this.ctx.emitters) if (e.Parent !== undefined && e.Rate > 0) e.Rate *= 0.4;
	}

	private setParticleRate(rate: number) {
		this.ctx.rate = rate;
		const alive = this.ctx.emitters.filter((e) => e.Parent !== undefined);
		for (const e of alive) e.TimeScale = this.frozen && this.setEmitters.has(e) ? 0 : rate;
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
			case "sub": {
				const spoken = this.speak(e);
				this.ui.subtitle(e.who, e.text, math.max(e.dur, spoken + 0.4), e.zh);
				break;
			}
			case "voice":
				this.speak(e);
				break;
			case "card":
				this.ui.nameCard(e.name, e.cn, e.epithet, e.dur);
				break;
			case "title":
				this.ui.showTitle(e.text, e.sub, e.dur, e.cn);
				break;
			case "fade":
				this.ui.fade(e.to, e.dur, e.color ?? new Color3(0, 0, 0));
				break;
			case "grade":
				this.post?.gradeTo(e.to, e.dur, this.tw);
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
				if (id !== "") this.sound(id, math.min(0.35 + 0.2 * s, 0.8), false).PlaybackSpeed = 1.1 - 0.08 * s;
				break;
			}
			case "speed":
				this.rate = math.max(e.scale, 0.01);
				break;
			case "lines":
				this.ui.speedLines(e.dur);
				break;
			case "move":
				this.actors.get(e.actor)?.moveTo(this.origin.mul(e.to), e.dur, e.ease, now, e.ghost === true, e.spin ?? 0, e.flip ?? 0);
				break;
			case "knock":
				this.actors.get(e.actor)?.knock(this.origin.VectorToWorldSpace(e.dir), e.power ?? 30, e.fade, now);
				break;
			case "wings": {
				const actor = this.actors.get(e.actor);
				const on = e.on;
				if (actor) this.tw.add(on ? 0.3 : 0.6, (k) => actor.setWings(on ? k : 1 - k));
				break;
			}
			case "charge": {
				const actor = this.actors.get(e.actor);
				if (actor) vfx.charge(this.ctx, () => actor.bladeTip(), e.dur, e.color ?? QI, e.scale ?? 1);
				break;
			}
			case "glint": {
				const tip = this.actors.get(e.actor)?.bladeTip();
				if (tip) vfx.glint(this.ctx, tip, QI);
				break;
			}
			case "still": {
				const actor = this.actors.get(e.actor);
				if (actor) actor.still = e.on;
				break;
			}
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
			case "aura":
				this.actors.get(e.actor)?.setAura(e.on);
				break;
			case "prop": {
				const p = this.def.props?.[e.name];
				if (!p) break;
				const from = this.propVals.get(e.name) ?? p.init;
				const name = e.name;
				const to = e.to;
				const curve = e.ease;
				this.tw.add(e.dur, (k) => {
					const value = from + (to - from) * ease(curve, k);
					this.propVals.set(name, value);
					p.set(this.root, value);
				});
				break;
			}
			case "freeze":
				this.frozen = e.on;
				this.setParticleRate(this.ctx.rate);
				break;
			case "break": {
				const blade = this.actors.get(e.actor)?.breakBlade();
				if (blade) {
					const [base, tip] = blade;
					vfx.swordShatter(this.ctx, base, tip, QI);
					vfx.burst(this.ctx, this.origin.PointToObjectSpace(tip), QI, 1);
				}
				break;
			}
			case "vfx":
				this.fireVfx(e);
				break;
			case "sfx": {
				const running = this.loops.get(e.name);
				if (running && running.Parent !== undefined) {
					TweenService.Create(running, new TweenInfo(e.fade ?? 0.5), { Volume: e.volume ?? 0.8 }).Play();
					break;
				}
				const id = SFX[e.name] ?? "";
				if (id !== "") {
					const s = this.sound(id, e.volume ?? 0.8, e.loop === true);
					if (e.pitch !== undefined) s.PlaybackSpeed = e.pitch;
					if (e.loop === true) this.loops.set(e.name, s);
				}
				break;
			}
			case "music": {
				const id = MUSIC[e.name] ?? "";
				const fade = e.fade ?? 1.5;
				const old = this.music;
				if (old && old.Parent !== undefined) {
					TweenService.Create(old, new TweenInfo(fade), { Volume: 0 }).Play();
					task.delay(fade, () => old.Destroy());
				}
				this.music = undefined;
				this.duckToken += 1;
				if (id !== "") {
					// Gak di-loop: tiap lagu dipotong pas di bagian yang cocok sama adegan (lihat `from`)
					const s = this.sound(id, 0, false);
					const from = e.from ?? 0;
					if (from > 0) {
						s.TimePosition = from;
						if (!s.IsLoaded) {
							const asked = os.clock();
							s.Loaded.Once(() => (s.TimePosition = from + (os.clock() - asked)));
						}
					}
					this.musicVol = e.volume ?? 0.5;
					TweenService.Create(s, new TweenInfo(fade), { Volume: this.musicVol }).Play();
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
				vfx.slash(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1, e.dur ?? 0.45, e.style === "ink");
				break;
			case "wave":
				vfx.wave(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1, e.dur ?? 0.5, e.style === "ink");
				break;
			case "burst":
				vfx.burst(this.ctx, e.at, color, e.scale ?? 1);
				break;
			case "ring":
				vfx.ring(this.ctx, e.at, e.scale ?? 20, color, e.normal);
				break;
			case "lightning":
				vfx.lightning(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1);
				break;
			case "cracks":
				vfx.cracks(this.ctx, e.at, e.scale ?? 1, e.color, e.life ?? 1.8);
				break;
			case "streak":
				vfx.streak(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1, e.dur ?? 0.3);
				break;
			case "cleave":
				vfx.cleave(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1, e.dur ?? 0.2, e.life ?? 1);
				break;
			case "spaceCrack":
				vfx.spaceCrack(this.ctx, e.at, e.scale ?? 1, color, e.stages ?? [], e.shatter, e.life ?? 3);
				break;
			case "rift":
				vfx.rift(this.ctx, e.at, e.to ?? e.at, color, e.scale ?? 1, e.life ?? 1.6);
				break;
			case "shard":
				vfx.shard(this.ctx, e.at, color, e.life ?? 10);
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
		if (this.bound) RunService.UnbindFromRenderStep(RENDER_NAME);
		this.bound = false;
		this.tw.clear();
		for (const [, actor] of this.actors) actor.destroy();
		this.actors.clear();
		this.root.Destroy();
		this.post?.destroy();
		for (const s of this.sounds) s.Destroy();
		this.sounds.clear();
		this.loops.clear();
		this.voiceFolder?.Destroy();
		this.voiceLines.clear();

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
