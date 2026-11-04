// Mode ringan buat HP dan grafik rendah (permintaan will 4 Nov: jangan berat, apalagi di HP).
// Low = tanpa DOF, afterimage dikit, partikel dan part set dikurangin, garis kecepatan lebih sedikit.

import { UserInputService } from "@rbxts/services";

export interface Quality {
	low: boolean;
	/** Pengali jumlah partikel. */
	particles: number;
	dof: boolean;
	/** Maksimal bayangan (afterimage) yang hidup bareng per aktor. 0 = mati. */
	ghosts: number;
	speedLines: number;
}

export function detectQuality(): Quality {
	const touchOnly = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
	let level = 10;
	const [ok, saved] = pcall(() => UserSettings().GetService("UserGameSettings").SavedQualityLevel);
	if (ok && saved !== Enum.SavedQualitySetting.Automatic) level = saved.Value;
	const low = touchOnly || level <= 4;
	return low
		? { low, particles: 0.4, dof: false, ghosts: 3, speedLines: 14 }
		: { low, particles: 1, dof: true, ghosts: 8, speedLines: 36 };
}
