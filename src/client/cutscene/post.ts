// Lighting dan post-processing selama cutscene: grading warna, bloom, DOF, impact frame.
// Semua nilai lama disimpan dan dibalikin pas cutscene selesai.

import { Lighting } from "@rbxts/services";
import { CutsceneLook, GradeProps } from "shared/cutscene/types";
import { Tweens } from "./tweens";

type Snapshot = Array<[Instance, string, unknown]>;

function apply(inst: Instance, props: object, snap: Snapshot) {
	const rec = inst as unknown as Record<string, unknown>;
	for (const [key, value] of pairs(props as Record<string, unknown>)) {
		snap.push([inst, key, rec[key]]);
		rec[key] = value;
	}
}

export class Post {
	private snap: Snapshot = [];
	private grade: ColorCorrectionEffect;
	private base: GradeProps;
	private dof?: DepthOfFieldEffect;
	private impactUntil = 0;

	constructor(look: CutsceneLook | undefined, useDof: boolean) {
		if (look?.lighting) apply(Lighting, look.lighting, this.snap);
		const atmosphere = Lighting.FindFirstChildOfClass("Atmosphere");
		if (atmosphere && look?.atmosphere) apply(atmosphere, look.atmosphere, this.snap);
		const bloom = Lighting.FindFirstChildOfClass("BloomEffect");
		if (bloom && look?.bloom) apply(bloom, look.bloom, this.snap);

		this.base = {
			Brightness: look?.grade?.Brightness ?? 0,
			Contrast: look?.grade?.Contrast ?? 0,
			Saturation: look?.grade?.Saturation ?? 0,
			TintColor: look?.grade?.TintColor ?? new Color3(1, 1, 1),
		};
		this.grade = new Instance("ColorCorrectionEffect");
		this.grade.Name = "CutsceneGrade";
		this.restoreGrade();
		this.grade.Parent = Lighting;

		if (useDof) {
			const dof = new Instance("DepthOfFieldEffect");
			dof.Name = "CutsceneDOF";
			dof.Enabled = false;
			dof.Parent = Lighting;
			this.dof = dof;
		}
	}

	/** Geser grading dasar pelan-pelan (waktu timeline). Impact frame tetap bisa nyela. */
	gradeTo(to: Partial<GradeProps>, dur: number, tw: Tweens) {
		const from = { ...this.base };
		const lerp = (a: number, b: number | undefined, k: number) => (b === undefined ? a : a + (b - a) * k);
		tw.add(dur, (k) => {
			this.base.Brightness = lerp(from.Brightness, to.Brightness, k);
			this.base.Contrast = lerp(from.Contrast, to.Contrast, k);
			this.base.Saturation = lerp(from.Saturation, to.Saturation, k);
			if (to.TintColor) this.base.TintColor = from.TintColor.Lerp(to.TintColor, k);
			if (this.impactUntil === 0) this.restoreGrade();
		});
	}

	/** Matiin DOF (dipanggil pengaman FPS). */
	disableDof() {
		this.dof?.Destroy();
		this.dof = undefined;
	}

	/** Fokus ke jarak `dist`. amount 0 = mati (hemat GPU). */
	focus(dist: number, amount: number) {
		const dof = this.dof;
		if (!dof) return;
		dof.Enabled = amount > 0.02;
		if (!dof.Enabled) return;
		dof.FocusDistance = dist;
		dof.InFocusRadius = math.max(dist * 0.35, 2);
		dof.FarIntensity = amount;
		dof.NearIntensity = amount * 0.6;
	}

	/** Frame hitam-putih kontras tinggi sekejap, kayak impact frame anime. */
	impactFrame(strength: number) {
		this.grade.Saturation = -1;
		this.grade.Contrast = 1 + strength;
		this.grade.Brightness = 0.12 * strength;
		this.grade.TintColor = new Color3(1, 1, 1);
		this.impactUntil = os.clock() + 0.05 + 0.02 * strength;
	}

	update() {
		if (this.impactUntil > 0 && os.clock() >= this.impactUntil) {
			this.impactUntil = 0;
			this.restoreGrade();
		}
	}

	private restoreGrade() {
		this.grade.Brightness = this.base.Brightness;
		this.grade.Contrast = this.base.Contrast;
		this.grade.Saturation = this.base.Saturation;
		this.grade.TintColor = this.base.TintColor;
	}

	destroy() {
		this.grade.Destroy();
		this.dof?.Destroy();
		for (let i = this.snap.size() - 1; i >= 0; i--) {
			const [inst, key, value] = this.snap[i];
			(inst as unknown as Record<string, unknown>)[key] = value;
		}
		this.snap.clear();
	}
}
