// Suara cutscene: musik, SFX, profil suara Mandarin (TTS), tekstur VFX.
// Musik + SFX diambil gratis dari Creator Store (4 Nov 2026), semua udah dicek bisa ke-load di Studio.
// Belum didengerin satu-satu: kalau ada yang gak cocok, ganti id-nya di sini aja. Id kosong = dilewati.

export const MUSIC: Record<string, string> = {
	// Semua dari album "Cezame China" (library musik film profesional, instrumen China asli), gratis di Creator Store.
	// Dicek 4 Nov: gak ada vokal (dites pakai AudioSpeechToText Roblox), bagian keras/pelan diukur pakai AudioAnalyzer.
	// "Yin Yang (Alternate No Choirs)": taiko, guzheng, seruling, tegang lalu perang. Dipotong dari detik 22.8
	// biar jeda hening di lagunya jatuh pas Bai Wuji ngangkat pedang di udara, dan klimaksnya pas tebasan raksasa.
	// Cadangan: 9046445896 Mystical Oracle, 9047430650 An Unexpected Revelation, 9046446330 Heart of Dragon
	prologWar: "rbxassetid://9046446608",
	// "Mystical Oracle (Alternate No Percs)": seruling dizi misterius, pas sosok diam muncul
	prologFigure: "rbxassetid://9046447265",
	// "An Unexpected Revelation": dari detik 62.2 bagian harpa yang sendu (berlutut, langit menutup mata),
	// lalu final heroik pas serpihan menembus awan ke dunia fana
	prologEnd: "rbxassetid://9047430650",
	sorrow: "",
};

export const SFX: Record<string, string> = {
	swordDraw: "",
	slash: "rbxassetid://125132253621935", // Sword Whoosh Slash
	bigSlash: "rbxassetid://110594287267319", // sword shing slash + ledakan
	impact: "rbxassetid://119977062667102", // cinematic impact boom
	boom: "rbxassetid://1835333323", // Angry Heavy Hitter Hit (APM)
	clash: "rbxassetid://9119072674", // denting pedang logam (Pro Sound Effects)
	crack: "rbxassetid://9114858583", // retakan es besar (Pro Sound Effects)
	shatter: "rbxassetid://132349765576039", // pecah kaca keras
	wind: "rbxassetid://112385924701681", // angin dingin menderu (loop)
	whoosh: "rbxassetid://9126229255", // whoosh cepat (Pro Sound Effects)
	thud: "rbxassetid://98059896877360", // hantaman jatuh
	thunder: "rbxassetid://9126099928", // petir besar (Pro Sound Effects)
	gong: "rbxassetid://134397657804669", // gong China
};

/**
 * Profil suara Mandarin buat AudioTextToSpeech. VoiceId Roblox: "501" pria Mandarin, "502" wanita Mandarin
 * (dicek 4 Nov 2026, id lain gagal). Pitch = AudioPitchShifter (1 = asli), reverb/echo 0..1.
 */
export interface VoiceDef {
	voiceId: string;
	speed: number;
	pitch: number;
	reverb: number;
	echo?: number;
	volume: number;
}

export const VOICES: Record<string, VoiceDef> = {
	narrator: { voiceId: "502", speed: 0.85, pitch: 0.96, reverb: 0.6, volume: 1 },
	bai: { voiceId: "501", speed: 0.92, pitch: 1, reverb: 0.2, volume: 1.1 },
	commander: { voiceId: "501", speed: 0.9, pitch: 0.8, reverb: 0.75, echo: 0.3, volume: 1.15 },
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
