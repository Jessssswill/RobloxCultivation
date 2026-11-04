// Suara cutscene. Isi id setelah musik/SFX dipilih (Creator Store) atau di-upload (izin will dulu).
// Id kosong = dilewati, jadi cutscene tetap jalan tanpa suara.

export const MUSIC: Record<string, string> = {
	prologWar: "",
	prologSilence: "",
	sorrow: "",
};

export const SFX: Record<string, string> = {
	swordDraw: "",
	slash: "",
	impact: "",
	clash: "",
	crack: "",
	shatter: "",
	wind: "",
	whoosh: "",
	thud: "",
};

// Tekstur VFX sendiri yang udah di-upload 1 Nov 2026 (assets/VFX/textures_v1/ASSET_IDS.txt).
export const TEX = {
	crescent: "rbxassetid://116325702137675",
	shockRing: "rbxassetid://120638941464407",
	glow: "rbxassetid://86794260657796",
	flare: "rbxassetid://74917717176224",
	smokeFlip: "rbxassetid://128189018436398",
	swirl: "rbxassetid://74831198929905",
	// spark belum di-upload, pakai bawaan Roblox
	spark: "rbxasset://textures/particles/sparkles_main.dds",
};
