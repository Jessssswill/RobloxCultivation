// Tingkat efek cutscene ikut setting grafik pemain (permintaan will 4 Nov: di laptop efeknya keren,
// pemain HP tinggal atur grafik sendiri). Grafik 1-3 ringan, 4-7 sedang, 8-10 tinggi.
// Grafik "Otomatis": PC tinggi, HP sedang. Ada pengaman FPS di runtime: kalau drop terus, efek diturunin.

import { UserInputService } from "@rbxts/services";
import { Tier } from "shared/cutscene/types";

export interface Quality {
	tier: Tier;
	low: boolean;
	/** Pengali jumlah partikel. */
	particles: number;
	dof: boolean;
	/** Maksimal bayangan (afterimage) yang hidup bareng per aktor. 0 = mati. */
	ghosts: number;
	speedLines: number;
	/** Lampu titik di VFX dan set. */
	lights: boolean;
}

const PRESETS: Record<Tier, Omit<Quality, "tier" | "low">> = {
	0: { particles: 0.4, dof: false, ghosts: 3, speedLines: 14, lights: false },
	1: { particles: 0.75, dof: true, ghosts: 5, speedLines: 24, lights: true },
	2: { particles: 1.3, dof: true, ghosts: 10, speedLines: 40, lights: true },
};

export function detectQuality(): Quality {
	let tier: Tier;
	const [ok, saved] = pcall(() => UserSettings().GetService("UserGameSettings").SavedQualityLevel);
	if (ok && saved !== Enum.SavedQualitySetting.Automatic) {
		const level = saved.Value;
		tier = level <= 3 ? 0 : level <= 7 ? 1 : 2;
	} else {
		const touchOnly = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
		tier = touchOnly ? 1 : 2;
	}
	return { tier, low: tier === 0, ...PRESETS[tier] };
}
