// UI cutscene: letterbox, vignette, subtitle ketik, kartu nama tokoh, judul, fade, garis kecepatan, tahan buat skip.
// Animasi teks pakai Tweens (waktu timeline), tahan-skip pakai waktu asli.

import { Players, TweenService, UserInputService } from "@rbxts/services";
import { Quality } from "./quality";
import { Tweens } from "./tweens";

const GOLD = Color3.fromRGB(232, 196, 120);
const SEAL = Color3.fromRGB(170, 32, 30);
const BAR = 0.11;
const HOLD_TO_SKIP = 0.8;
const SERIF = Font.fromEnum(Enum.Font.Merriweather);
const SERIF_ITALIC = new Font(SERIF.Family, Enum.FontWeight.Regular, Enum.FontStyle.Italic);
const TITLE = Font.fromEnum(Enum.Font.Antique);

function frame(parent: Instance, props: Partial<WritableInstanceProperties<Frame>>) {
	const f = new Instance("Frame");
	f.BorderSizePixel = 0;
	f.BackgroundColor3 = new Color3(0, 0, 0);
	for (const [k, v] of pairs(props as Record<string, unknown>)) (f as unknown as Record<string, unknown>)[k] = v;
	f.Parent = parent;
	return f;
}

function label(parent: Instance, props: Partial<WritableInstanceProperties<TextLabel>>) {
	const l = new Instance("TextLabel");
	l.BackgroundTransparency = 1;
	l.TextColor3 = new Color3(1, 1, 1);
	l.TextScaled = true;
	l.FontFace = SERIF;
	l.TextTransparency = 1;
	for (const [k, v] of pairs(props as Record<string, unknown>)) (l as unknown as Record<string, unknown>)[k] = v;
	l.Parent = parent;
	return l;
}

function stroke(parent: GuiObject, thickness = 1.5) {
	const s = new Instance("UIStroke");
	s.Thickness = thickness;
	s.Transparency = 0.4;
	s.Parent = parent;
	return s;
}

/** Cap segel merah (印章) ala lukisan China: kotak merah, huruf putih, muncul kayak dicap. */
function seal(parent: Instance, position: UDim2, size: number, zindex: number): [Frame, TextLabel, UIScale] {
	const f = frame(parent, {
		BackgroundColor3: SEAL,
		BackgroundTransparency: 1,
		Size: UDim2.fromScale(size, size),
		SizeConstraint: Enum.SizeConstraint.RelativeYY,
		Position: position,
		AnchorPoint: new Vector2(0.5, 0.5),
		ZIndex: zindex,
	});
	const corner = new Instance("UICorner");
	corner.CornerRadius = new UDim(0.1, 0);
	corner.Parent = f;
	const text = label(f, {
		Size: UDim2.fromScale(0.86, 0.86),
		Position: UDim2.fromScale(0.5, 0.5),
		AnchorPoint: new Vector2(0.5, 0.5),
		TextColor3: Color3.fromRGB(250, 236, 222),
		FontFace: TITLE,
		LineHeight: 0.9,
		ZIndex: zindex,
	});
	const scale = new Instance("UIScale");
	scale.Parent = f;
	return [f, text, scale];
}

/** "BAI WUJI" jadi "B A I   W U J I" biar kerasa judul film. */
function spaced(text: string) {
	const [s] = text.gsub(".", "%0 ");
	return s.sub(1, -2);
}

export class CutsceneUI {
	private gui: ScreenGui;
	private tw: Tweens;
	private top: Frame;
	private bottom: Frame;
	private fader: Frame;
	private subWho: TextLabel;
	private subZh: TextLabel;
	private subText: TextLabel;
	private subToken = 0;
	private card: Frame;
	private cardParts: TextLabel[];
	private cardStripe: Frame;
	private cardSeal: [Frame, TextLabel, UIScale];
	private titleSeal: [Frame, TextLabel, UIScale];
	private title: TextLabel;
	private titleCn: TextLabel;
	private titleCnScale: UIScale;
	private titleSub: TextLabel;
	private lines: Frame[] = [];
	private linesUntil = 0;
	private skipBtn: TextButton;
	private skipFill: Frame;
	private holding = false;
	private holdProgress = 0;
	private conns = new Array<RBXScriptConnection>();

	constructor(q: Quality, tw: Tweens, private onSkip: () => void) {
		this.tw = tw;
		const gui = new Instance("ScreenGui");
		gui.Name = "CutsceneUI";
		gui.IgnoreGuiInset = true;
		gui.ResetOnSpawn = false;
		gui.DisplayOrder = 50;
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		this.gui = gui;

		// Vignette tipis di kiri-kanan
		for (const side of [0, 1]) {
			const v = frame(gui, { Size: UDim2.fromScale(0.18, 1), Position: UDim2.fromScale(side === 0 ? 0 : 0.82, 0) });
			const g = new Instance("UIGradient");
			g.Transparency = new NumberSequence([
				new NumberSequenceKeypoint(0, side === 0 ? 0.55 : 1),
				new NumberSequenceKeypoint(1, side === 0 ? 1 : 0.55),
			]);
			g.Parent = v;
		}

		// Garis kecepatan (ditaruh sebelum letterbox biar ketutup bar)
		for (let i = 0; i < q.speedLines; i++) {
			this.lines.push(frame(gui, { BackgroundColor3: new Color3(1, 1, 1), AnchorPoint: new Vector2(0.5, 0.5), Visible: false }));
		}

		this.top = frame(gui, { Size: UDim2.fromScale(1, 0), ZIndex: 5 });
		this.bottom = frame(gui, { Size: UDim2.fromScale(1, 0), Position: UDim2.fromScale(0, 1), AnchorPoint: new Vector2(0, 1), ZIndex: 5 });

		// Subtitle di dalam bar bawah, kayak bioskop
		this.subWho = label(gui, {
			Size: UDim2.fromScale(0.6, 0.026),
			Position: UDim2.fromScale(0.5, 0.905),
			AnchorPoint: new Vector2(0.5, 0.5),
			TextColor3: GOLD,
			FontFace: TITLE,
			ZIndex: 6,
		});
		this.subText = label(gui, {
			Size: UDim2.fromScale(0.72, 0.036),
			Position: UDim2.fromScale(0.5, 0.945),
			AnchorPoint: new Vector2(0.5, 0.5),
			ZIndex: 6,
		});
		const subSize = new Instance("UITextSizeConstraint");
		subSize.MaxTextSize = 30;
		subSize.Parent = this.subText;
		// Baris Mandarin (yang diucapin), di atas terjemahan Inggris
		this.subZh = label(gui, {
			Size: UDim2.fromScale(0.6, 0.03),
			Position: UDim2.fromScale(0.5, 0.931),
			AnchorPoint: new Vector2(0.5, 0.5),
			TextColor3: Color3.fromRGB(246, 236, 212),
			ZIndex: 6,
		});
		const zhSize = new Instance("UITextSizeConstraint");
		zhSize.MaxTextSize = 28;
		zhSize.Parent = this.subZh;

		// Kartu nama tokoh ala donghua: huruf Han vertikal, garis segel merah, nama Inggris, julukan
		this.card = frame(gui, { Size: UDim2.fromScale(0.4, 0.34), Position: UDim2.fromScale(0.06, 0.5), AnchorPoint: new Vector2(0, 0.5), BackgroundTransparency: 1, ZIndex: 4 });
		this.cardStripe = frame(this.card, { BackgroundColor3: SEAL, Size: new UDim2(0, 5, 0.8, 0), Position: UDim2.fromScale(0, 0.1), BackgroundTransparency: 1, ZIndex: 4 });
		const cn = label(this.card, { Name: "Cn", Size: UDim2.fromScale(0.2, 1), Position: new UDim2(0, 16, 0, 0), ZIndex: 4 });
		const name = label(this.card, { Name: "Name", Size: UDim2.fromScale(0.72, 0.22), Position: UDim2.fromScale(0.27, 0.3), TextColor3: GOLD, FontFace: TITLE, TextXAlignment: Enum.TextXAlignment.Left, ZIndex: 4 });
		const epithet = label(this.card, { Name: "Epithet", Size: UDim2.fromScale(0.72, 0.1), Position: UDim2.fromScale(0.27, 0.56), FontFace: SERIF_ITALIC, TextXAlignment: Enum.TextXAlignment.Left, ZIndex: 4 });
		stroke(cn, 2);
		stroke(name);
		this.cardParts = [cn, name, epithet];
		this.cardSeal = seal(this.card, UDim2.fromScale(0.33, 0.8), 0.15, 4);

		this.title = label(gui, { Size: UDim2.fromScale(0.8, 0.09), Position: UDim2.fromScale(0.5, 0.46), AnchorPoint: new Vector2(0.5, 0.5), FontFace: TITLE, TextColor3: GOLD, ZIndex: 8 });
		this.titleCn = label(gui, { Size: UDim2.fromScale(0.5, 0.15), Position: UDim2.fromScale(0.5, 0.33), AnchorPoint: new Vector2(0.5, 0.5), FontFace: TITLE, TextColor3: Color3.fromRGB(250, 240, 220), ZIndex: 8 });
		stroke(this.titleCn, 2);
		this.titleCnScale = new Instance("UIScale");
		this.titleCnScale.Parent = this.titleCn;
		this.titleSeal = seal(gui, UDim2.fromScale(0.71, 0.37), 0.075, 8);
		this.titleSub = label(gui, { Size: UDim2.fromScale(0.5, 0.035), Position: UDim2.fromScale(0.5, 0.54), AnchorPoint: new Vector2(0.5, 0.5), FontFace: SERIF_ITALIC, ZIndex: 8 });

		this.fader = frame(gui, { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 7 });

		// Tahan buat skip: tombol (mouse / sentuh), Space / Enter, atau B di gamepad
		const touch = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
		const btn = new Instance("TextButton");
		btn.AutoButtonColor = false;
		btn.BackgroundColor3 = new Color3(0, 0, 0);
		btn.BackgroundTransparency = 0.4;
		btn.BorderSizePixel = 0;
		btn.Size = UDim2.fromScale(touch ? 0.16 : 0.11, 0.05);
		btn.Position = UDim2.fromScale(0.975, 0.945);
		btn.AnchorPoint = new Vector2(1, 0.5);
		btn.Text = touch ? "Hold to skip" : "Hold Space to skip";
		btn.TextScaled = true;
		btn.TextColor3 = new Color3(1, 1, 1);
		btn.TextTransparency = 0.35;
		btn.FontFace = SERIF;
		btn.ZIndex = 9;
		const pad = new Instance("UIPadding");
		pad.PaddingTop = new UDim(0.22, 0);
		pad.PaddingBottom = new UDim(0.22, 0);
		pad.Parent = btn;
		const corner = new Instance("UICorner");
		corner.CornerRadius = new UDim(0.3, 0);
		corner.Parent = btn;
		this.skipFill = frame(btn, { BackgroundColor3: GOLD, BackgroundTransparency: 0.2, Size: new UDim2(0, 0, 0, 2), Position: UDim2.fromScale(0, 1), AnchorPoint: new Vector2(0, 1), ZIndex: 9 });
		btn.Parent = gui;
		this.skipBtn = btn;

		this.conns.push(
			btn.InputBegan.Connect((input) => {
				const t = input.UserInputType;
				if (t === Enum.UserInputType.MouseButton1 || t === Enum.UserInputType.Touch) this.holding = true;
			}),
			btn.InputEnded.Connect((input) => {
				const t = input.UserInputType;
				if (t === Enum.UserInputType.MouseButton1 || t === Enum.UserInputType.Touch) this.holding = false;
			}),
			UserInputService.InputBegan.Connect((input, processed) => {
				const k = input.KeyCode;
				if (!processed && (k === Enum.KeyCode.Space || k === Enum.KeyCode.Return || k === Enum.KeyCode.ButtonB)) this.holding = true;
			}),
			UserInputService.InputEnded.Connect((input) => {
				const k = input.KeyCode;
				if (k === Enum.KeyCode.Space || k === Enum.KeyCode.Return || k === Enum.KeyCode.ButtonB) this.holding = false;
			}),
		);

		gui.Parent = Players.LocalPlayer.WaitForChild("PlayerGui");
	}

	letterbox(show: boolean, dur = 0.6) {
		const info = new TweenInfo(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
		TweenService.Create(this.top, info, { Size: UDim2.fromScale(1, show ? BAR : 0) }).Play();
		TweenService.Create(this.bottom, info, { Size: UDim2.fromScale(1, show ? BAR : 0) }).Play();
	}

	subtitle(who: string | undefined, text: string, dur: number, zh?: string) {
		const token = ++this.subToken;
		const shown = text.gsub("{player}", Players.LocalPlayer.DisplayName)[0];
		const two = zh !== undefined && zh !== "";
		this.subWho.Text = who !== undefined ? spaced(who.upper()) : "";
		this.subZh.Text = two ? zh : "";
		this.subText.Text = shown;
		this.subText.MaxVisibleGraphemes = 0;
		// Dua bahasa: nama, Mandarin, Inggris (lebih kecil). Satu bahasa: layout lama
		this.subWho.Position = UDim2.fromScale(0.5, two ? 0.903 : 0.905);
		this.subWho.Size = UDim2.fromScale(0.6, two ? 0.022 : 0.026);
		this.subText.Position = UDim2.fromScale(0.5, two ? 0.963 : 0.945);
		this.subText.Size = UDim2.fromScale(0.72, two ? 0.027 : 0.036);
		const graphemes = (utf8.len(shown)[0] as number | undefined) ?? shown.size();
		this.tw.add(0.15, (a) => {
			this.subWho.TextTransparency = 1 - a;
			this.subZh.TextTransparency = 1 - a;
			this.subText.TextTransparency = 1 - a;
		});
		// Efek ketik: cepat, maksimal 1 detik
		this.tw.add(math.min(graphemes * 0.025, 1), (a) => {
			if (token === this.subToken) this.subText.MaxVisibleGraphemes = math.floor(graphemes * a + 0.5);
		});
		this.tw.after(dur, () => {
			if (token !== this.subToken) return;
			this.tw.add(0.25, (a) => {
				if (token !== this.subToken) return;
				this.subWho.TextTransparency = a;
				this.subZh.TextTransparency = a;
				this.subText.TextTransparency = a;
			});
		});
	}

	nameCard(name: string, cn: string | undefined, epithet: string | undefined, dur: number) {
		const [cnLabel, nameLabel, epithetLabel] = this.cardParts;
		const chars: string[] = [];
		for (const [, code] of utf8.codes(cn ?? "")) chars.push(utf8.char(code));
		cnLabel.Text = chars.join("\n");
		nameLabel.Text = spaced(name);
		epithetLabel.Text = epithet ?? "";
		const [sealFrame, sealText, sealScale] = this.cardSeal;
		sealText.Text = chars[0] ?? "";
		const fadeTo = (a: number) => {
			for (const l of this.cardParts) l.TextTransparency = a;
			this.cardStripe.BackgroundTransparency = a;
		};
		this.tw.add(0.5, (a) => {
			const e = 1 - (1 - a) ** 3;
			this.card.Position = UDim2.fromScale(0.02 + 0.04 * e, 0.5);
			fadeTo(1 - e);
		});
		if (chars.size() > 0) this.tw.after(0.55, () => this.stamp(sealFrame, sealText, sealScale));
		this.tw.after(dur, () =>
			this.tw.add(0.6, (a) => {
				fadeTo(a);
				if (chars.size() > 0) {
					sealFrame.BackgroundTransparency = math.max(sealFrame.BackgroundTransparency, a);
					sealText.TextTransparency = math.max(sealText.TextTransparency, a);
				}
			}),
		);
	}

	/** Animasi cap: jatuh dari besar ke ukuran asli dengan cepat, kayak stempel ditekan. */
	private stamp(f: Frame, text: TextLabel, scale: UIScale) {
		this.tw.add(0.16, (a) => {
			const e = a * a;
			scale.Scale = 1.8 - 0.8 * e;
			f.BackgroundTransparency = 1 - e;
			text.TextTransparency = 1 - e;
		});
	}

	showTitle(text: string, sub: string | undefined, dur: number, cn?: string) {
		this.title.Text = spaced(text);
		this.titleSub.Text = sub ?? "";
		this.titleCn.Text = cn ?? "";
		const [sealFrame, sealText, sealScale] = this.titleSeal;
		// Segel 2 huruf pertama, ditumpuk vertikal (逆天)
		const chars: string[] = [];
		for (const [, code] of utf8.codes(cn ?? "")) chars.push(utf8.char(code));
		sealText.Text = chars.size() >= 2 ? `${chars[0]}\n${chars[1]}` : chars[0] ?? "";
		if (chars.size() > 0) this.tw.after(1.1, () => this.stamp(sealFrame, sealText, sealScale));
		this.tw.add(1, (a) => {
			this.title.TextTransparency = 1 - a;
			this.titleSub.TextTransparency = 1 - a;
		});
		// Huruf Han muncul duluan, turun pelan dari agak besar
		this.tw.add(1.6, (a) => {
			const e = 1 - (1 - a) ** 3;
			this.titleCn.TextTransparency = 1 - math.min(a * 1.6, 1);
			this.titleCnScale.Scale = 1.15 - 0.15 * e;
		});
		this.tw.after(dur - 1, () =>
			this.tw.add(1, (a) => {
				this.title.TextTransparency = a;
				this.titleSub.TextTransparency = a;
				this.titleCn.TextTransparency = a;
				if (chars.size() > 0) {
					sealFrame.BackgroundTransparency = math.max(sealFrame.BackgroundTransparency, a);
					sealText.TextTransparency = math.max(sealText.TextTransparency, a);
				}
			}),
		);
	}

	/** to = 1 hitam penuh (atau warna lain), 0 bening. Waktu timeline. */
	fade(to: number, dur: number, color?: Color3) {
		if (color) this.fader.BackgroundColor3 = color;
		const from = 1 - this.fader.BackgroundTransparency;
		this.tw.add(dur, (a) => (this.fader.BackgroundTransparency = 1 - (from + (to - from) * a)));
	}

	/** Fade pakai waktu asli (dipakai pas skip dan keluar dari cutscene). */
	fadeReal(to: number, dur: number, color?: Color3) {
		if (color) this.fader.BackgroundColor3 = color;
		TweenService.Create(this.fader, new TweenInfo(dur), { BackgroundTransparency: 1 - to }).Play();
	}

	speedLines(seconds: number) {
		this.linesUntil = math.max(this.linesUntil, os.clock() + seconds);
	}

	hideSkip() {
		this.skipBtn.Visible = false;
		this.holding = false;
	}

	/** Dipanggil tiap frame dengan dt waktu asli. */
	update(dt: number) {
		// Tahan buat skip
		if (this.skipBtn.Visible) {
			this.holdProgress = this.holding ? this.holdProgress + dt / HOLD_TO_SKIP : math.max(this.holdProgress - dt * 3, 0);
			this.skipFill.Size = new UDim2(math.clamp(this.holdProgress, 0, 1), 0, 0, 2);
			this.skipBtn.TextTransparency = this.holding ? 0 : 0.35;
			if (this.holdProgress >= 1) {
				this.hideSkip();
				this.onSkip();
			}
		}

		// Garis kecepatan: posisi acak tiap frame biar kerasa getar
		const active = os.clock() < this.linesUntil;
		const size = this.gui.AbsoluteSize;
		const cx = size.X / 2;
		const cy = size.Y / 2;
		const reach = math.max(cx, cy);
		for (const line of this.lines) {
			line.Visible = active;
			if (!active) continue;
			const ang = math.random() * math.pi * 2;
			const len = reach * (0.35 + math.random() * 0.4);
			const r = reach * 0.45 + len / 2;
			line.Size = new UDim2(0, 2 + math.random() * 3, 0, len);
			line.Position = new UDim2(0, cx + math.cos(ang) * r, 0, cy + math.sin(ang) * r);
			line.Rotation = math.deg(ang) + 90;
			line.BackgroundTransparency = 0.25 + math.random() * 0.5;
		}
	}

	destroy() {
		for (const c of this.conns) c.Disconnect();
		this.conns.clear();
		this.gui.Destroy();
	}
}
