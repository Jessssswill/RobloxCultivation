// Skala senjata dan sarung ngikutin tinggi avatar pemain (keputusan Will 19 Okt 2026).
// Ukuran dasar senjata (5,5 / 6 / 6,5 stud) dibikin buat avatar R15 standar setinggi REF_HEIGHT.
// Versi roblox-ts dari draft Luau assets/WeaponScale/WeaponScale.lua.

/** Tinggi avatar standar; kalibrasi di Studio pakai avatarHeight() avatar default. */
export const REF_HEIGHT = 5.2;
export const MIN_SCALE = 0.8;
export const MAX_SCALE = 1.6;

/** Tinggi avatar dari telapak kaki sampai ubun-ubun, tanpa aksesoris (rambut/topi nggak dihitung). */
export function avatarHeight(character: Model): number {
	const hum = character.FindFirstChildOfClass("Humanoid");
	const root = character.FindFirstChild("HumanoidRootPart") as BasePart | undefined;
	const head = character.FindFirstChild("Head") as BasePart | undefined;
	if (!hum || !root || !head) return REF_HEIGHT;
	const ground = root.Position.Y - root.Size.Y / 2 - hum.HipHeight;
	const top = head.Position.Y + head.Size.Y / 2;
	return math.max(top - ground, 1);
}

export function factorFor(character: Model): number {
	return math.clamp(avatarHeight(character) / REF_HEIGHT, MIN_SCALE, MAX_SCALE);
}

/** Geser posisi CFrame sebesar k kali, rotasinya tetap. */
function scaleCFrame(cf: CFrame, k: number): CFrame {
	return cf.sub(cf.Position).add(cf.Position.mul(k));
}

function scaleSequence(seq: NumberSequence, k: number): NumberSequence {
	return new NumberSequence(
		seq.Keypoints.map((p) => new NumberSequenceKeypoint(p.Time, p.Value * k, p.Envelope * k)),
	);
}

/** Skala Tool relatif ke Handle. Aman dipanggil berkali-kali: yang disimpan cuma faktor total. */
export function scaleTool(tool: Tool, target: number) {
	const current = (tool.GetAttribute("AppliedScale") as number | undefined) ?? 1;
	const k = target / current;
	if (math.abs(k - 1) < 0.01) return;
	const handle = tool.FindFirstChild("Handle") as BasePart | undefined;
	if (!handle) return;
	for (const d of tool.GetDescendants()) {
		if (d.IsA("BasePart")) {
			const rel = handle.CFrame.ToObjectSpace(d.CFrame);
			d.Size = d.Size.mul(k);
			if (d !== handle) d.CFrame = handle.CFrame.mul(scaleCFrame(rel, k));
		} else if (d.IsA("Attachment")) {
			d.Position = d.Position.mul(k);
		} else if (d.IsA("JointInstance")) {
			d.C0 = scaleCFrame(d.C0, k);
			d.C1 = scaleCFrame(d.C1, k);
		} else if (d.IsA("Beam")) {
			d.Width0 *= k;
			d.Width1 *= k;
		} else if (d.IsA("ParticleEmitter")) {
			d.Size = scaleSequence(d.Size, k);
		}
	}
	tool.Grip = scaleCFrame(tool.Grip, k);
	tool.SetAttribute("AppliedScale", target);
}

/** Sarung (Model) cukup pakai ScaleTo bawaan; offset pinggang di AttachScabbard juga harus dikali faktor yang sama. */
export function scaleModel(model: Model, target: number) {
	model.ScaleTo(target);
}
