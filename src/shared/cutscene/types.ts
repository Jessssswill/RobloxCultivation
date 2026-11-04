// Format data cutscene. Satu cutscene = satu timeline: kunci kamera + daftar event berurutan waktu.
// Semua posisi relatif ke origin cutscene (part anchor di Workspace.CutsceneAnchors, atau origin bawaan).
// Waktu (t) itu waktu timeline: kena slow-mo dan hitstop, jadi semua gerakan ikut melambat bareng.

export type Ease = "linear" | "in" | "out" | "inOut" | "back" | "expoOut";

/** Tingkat grafik: 0 ringan, 1 sedang, 2 tinggi. Ikut setting grafik pemain (lihat client/cutscene/quality.ts). */
export type Tier = 0 | 1 | 2;

export interface GradeProps {
	Brightness: number;
	Contrast: number;
	Saturation: number;
	TintColor: Color3;
}

export interface CamKey {
	t: number;
	/** Posisi kamera. Kalau `follow` diisi, ini offset dari aktor itu. */
	pos: Vector3;
	/** Titik yang dilihat. Kalau `track` diisi, ini offset dari aktor itu. */
	look: Vector3;
	follow?: string;
	track?: string;
	fov?: number;
	/** Miring kamera, derajat. */
	roll?: number;
	/** Blur latar (depth of field) 0..1. Fokus otomatis ke titik `look`. */
	dof?: number;
	/** Easing dari key sebelumnya ke key ini. */
	ease?: Ease;
	/** Ganti shot: kamera loncat ke key ini tanpa transisi. */
	cut?: boolean;
}

export interface ActorDef {
	id: string;
	/**
	 * player     = salinan avatar pemain sendiri (pemain = tokoh utama).
	 * template   = model R15 dari ReplicatedStorage.CutsceneRigs. Kalau gak ada, pakai Mannequin dicat `color`.
	 * silhouette = Mannequin dicat satu warna (pasukan, sosok misterius).
	 */
	look: "player" | "template" | "silhouette";
	template?: string;
	color?: Color3;
	material?: Enum.Material;
	weapon?: "jian" | "spear";
	/** Warna bayangan (afterimage) waktu gerak cepat. */
	ghostColor?: Color3;
	/** Garis cahaya di pinggir badan (Highlight). Grafik tinggi semua, grafik sedang cuma yang `key`. */
	outline?: { color: Color3; alpha?: number; key?: boolean };
	/** Aura qi di badan, dinyalain lewat event "aura". Grafik sedang ke atas. */
	aura?: Color3;
	/** CFrame telapak kaki, relatif ke origin. */
	start: CFrame;
	hidden?: boolean;
}

interface At {
	t: number;
}

export type CutEvent = At &
	(
		/** Subtitle. Kalau `zh` + `voice` diisi, kalimat Mandarin-nya diucapin (TTS Roblox) dan ikut tampil di atas teks Inggris. */
		| { kind: "sub"; who?: string; text: string; dur: number; zh?: string; voice?: string }
		/** Cuma suara Mandarin, tanpa subtitle (misal narator pas judul). */
		| { kind: "voice"; zh: string; voice: string }
		| { kind: "card"; name: string; cn?: string; epithet?: string; dur: number }
		| { kind: "title"; text: string; cn?: string; sub?: string; dur: number }
		/** Ubah grading warna pelan-pelan (misal dunia jadi pucat pas waktu "berhenti"). */
		| { kind: "grade"; to: Partial<GradeProps>; dur: number }
		| { kind: "aura"; actor: string; on: boolean }
		/** Gerakin properti set milik scene (CutsceneDef.props), misal Mata Langit membuka/menutup. */
		| { kind: "prop"; name: string; to: number; dur: number; ease?: Ease }
		/** Bekukan partikel set (butiran qi diam di udara) pas momen "waktu berhenti". */
		| { kind: "freeze"; on: boolean }
		| { kind: "fade"; to: number; dur: number; color?: Color3 }
		| { kind: "shake"; mag: number; dur: number }
		/** Hitstop + impact frame + garis kecepatan + guncangan. Inti rasa donghua. */
		| { kind: "impact"; strength?: number }
		/** Kecepatan timeline (slow-mo). 1 = normal. */
		| { kind: "speed"; scale: number }
		| { kind: "lines"; dur: number }
		| { kind: "move"; actor: string; to: CFrame; dur: number; ease?: Ease; ghost?: boolean }
		| { kind: "pose"; actor: string; pose: string; dur: number; ease?: Ease }
		| { kind: "anim"; actor: string; animId: string; speed?: number }
		| { kind: "show"; actor: string }
		| { kind: "hide"; actor: string }
		| { kind: "break"; actor: string }
		| {
				kind: "vfx";
				name: "slash" | "burst" | "ring" | "fall" | "debris" | "collapse" | "wave" | "lightning" | "cracks";
				at: Vector3;
				to?: Vector3;
				/** Titik kontrol kurva buat fall (Bezier). */
				via?: Vector3;
				/** Arah normal buat ring (default ke atas). */
				normal?: Vector3;
				/** Nama folder set buat collapse. */
				target?: string;
				dur?: number;
				scale?: number;
				color?: Color3;
				/** "ink" = lapisan tinta hitam + cipratan tinta (ciri khas pedang Bai Wuji). */
				style?: "ink";
		  }
		| { kind: "sfx"; name: string; volume?: number; pitch?: number; loop?: boolean }
		| { kind: "music"; name: string; volume?: number; fade?: number }
	);

export interface CutsceneLook {
	lighting?: Partial<{
		ClockTime: number;
		Brightness: number;
		ExposureCompensation: number;
		Ambient: Color3;
		OutdoorAmbient: Color3;
		FogColor: Color3;
		FogEnd: number;
	}>;
	atmosphere?: Partial<{ Density: number; Haze: number; Glare: number; Offset: number; Color: Color3; Decay: Color3 }>;
	grade?: Partial<GradeProps>;
	bloom?: Partial<{ Intensity: number; Size: number; Threshold: number }>;
	/** Goyang kamera tangan (derajat). Bikin shot gak kaku. */
	handheld?: number;
}

export interface CutsceneDef {
	id: string;
	/** Judul di menu tonton ulang (Kuil Ingatan). */
	title: string;
	chapter: string;
	length: number;
	/** Nama part di Workspace.CutsceneAnchors. Kalau gak ketemu, pakai origin. */
	anchor?: string;
	origin: CFrame;
	look?: CutsceneLook;
	/** Bikin set lokal (cuma di client yang nonton). Detail ikut tier grafik. */
	build?: (root: Folder, tier: Tier) => void;
	/** Properti set yang bisa dianimasiin lewat event "prop". `set` dipanggil tiap frame selama tween. */
	props?: Record<string, { init: number; set: (root: Folder, value: number) => void }>;
	actors: ActorDef[];
	camera: CamKey[];
	events: CutEvent[];
}
