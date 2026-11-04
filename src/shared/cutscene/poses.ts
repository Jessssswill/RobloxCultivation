// Pose keyframe buat aktor cutscene, tanpa upload animasi. Tiap pose = rotasi sendi R15 (derajat X, Y, Z)
// plus opsional geser badan turun (dy, khusus sendi Root). Sendi yang gak disebut balik ke netral.
// Aktor gak loncat dari pose ke pose: tiap sendi ditarik pegas ke target (lihat client/cutscene/actors.ts),
// jadi ada momentum, lewat dikit, dan ujung badan telat dikit (gerak susulan).
//
// Arah (dicek 4 Nov, rumus CFrame.Angles):
// - Root / Waist: +X condong ke belakang, -X condong ke depan. +Y putar ke kiri. +Z miring ke kiri.
// - Neck: +X dongak, -X nunduk. +Y noleh kiri.
// - Shoulder / Hip: +X angkat ke depan. RightShoulder/RightHip +Z ke samping kanan, Left -Z ke samping kiri.
// - Elbow: +X nekuk. Knee: -X nekuk. Ankle: +X ujung kaki naik.
// - Wrist kanan: +X ujung pedang naik, -X turun (pedang sejajar -Z tangan). -90 = bilah sejajar lengan.
// Telapak kaki: dy Root + Ankle tiap pose diukur di Studio (rig tinggi 1.05) biar kaki napak, gak nembus tanah.

export type JointRot = [number, number, number] | [number, number, number, number];
export type Pose = Partial<Record<string, JointRot>>;

export const POSES: Record<string, Pose> = {
	idle: {},
	// Siaga jian: pedang serong ke depan, kuda-kuda rendah
	guard: {
		Root: [0, 0, 0, -0.07],
		Waist: [-6, -20, 0],
		Neck: [2, 15, 0],
		RightShoulder: [65, 0, 15],
		RightElbow: [35, 0, 0],
		RightWrist: [-55, 0, 0],
		LeftShoulder: [35, 0, -25],
		LeftElbow: [70, 0, 0],
		RightHip: [25, 0, 8],
		RightKnee: [-32, 0, 0],
		LeftHip: [-12, 0, -8],
		LeftKnee: [-28, 0, 0],
		RightAnkle: [7, 0, 0],
		LeftAnkle: [20, 0, 0],
	},
	// Kuda-kuda cabut: badan melintir, pedang rendah di belakang, dua jari kiri ke depan (pedang jari ala kultivator)
	drawStance: {
		Root: [0, 0, 0, -0.15],
		Waist: [-10, -38, 0],
		Neck: [0, 34, 0],
		RightShoulder: [-28, 0, 38],
		RightElbow: [18, 0, 0],
		RightWrist: [-15, 0, 0],
		LeftShoulder: [75, 0, -12],
		LeftElbow: [55, 0, 0],
		LeftWrist: [20, 0, 0],
		RightHip: [-18, 0, 10],
		RightKnee: [-25, 0, 0],
		LeftHip: [38, 0, -10],
		LeftKnee: [-45, 0, 0],
		RightAnkle: [23, 0, 0],
		LeftAnkle: [6, 0, 0],
	},
	// Tebasan kiri ke kanan: awalan lengan nyilang ke kiri
	slashWindup: {
		Root: [0, 0, 0, -0.02],
		Waist: [-5, 45, 0],
		Neck: [0, -30, 0],
		RightShoulder: [100, 0, -55],
		RightElbow: [55, 0, 0],
		RightWrist: [-40, 0, 0],
		LeftShoulder: [25, 0, -35],
		RightHip: [15, 0, 0],
		LeftKnee: [-30, 0, 0],
		RightAnkle: [-15, 0, 0],
		LeftAnkle: [12, 0, 0],
	},
	// Akhir tebasan kiri ke kanan: lengan lurus ke kanan belakang, bilah datar sejajar lengan
	slashFollow: {
		Root: [0, 0, 0, -0.23],
		Waist: [-10, -45, 0],
		Neck: [0, 35, 0],
		RightShoulder: [10, 0, 82],
		RightElbow: [5, 0, 0],
		RightWrist: [-90, 0, 0],
		LeftShoulder: [20, 0, -72],
		LeftElbow: [25, 0, 0],
		RightHip: [38, 0, 0],
		RightKnee: [-48, 0, 0],
		LeftHip: [-28, 0, 0],
		LeftKnee: [-12, 0, 0],
		RightAnkle: [10, 0, 0],
		LeftAnkle: [20, 0, 0],
	},
	// Siap tebasan putar: jongkok, badan melintir ke kiri, pedang di belakang
	spinReady: {
		Root: [0, 0, 0, -0.33],
		Waist: [-18, 50, 0],
		Neck: [0, -40, 0],
		RightShoulder: [60, 0, -60],
		RightElbow: [40, 0, 0],
		RightWrist: [-30, 0, 0],
		LeftShoulder: [10, 0, -45],
		RightHip: [45, 0, 10],
		RightKnee: [-70, 0, 0],
		LeftHip: [-10, 0, -15],
		LeftKnee: [-50, 0, 0],
		RightAnkle: [24, 0, 0],
		LeftAnkle: [37, 0, 0],
	},
	// Tebasan putar: lengan lurus ke samping kanan, bilah datar sejajar lengan (nyapu lingkaran pas badan muter)
	spinSlash: {
		Root: [0, 0, 0, -0.13],
		Waist: [-10, -20, 0],
		Neck: [0, 15, 0],
		RightShoulder: [10, 0, 85],
		RightElbow: [4, 0, 0],
		RightWrist: [-90, 0, 0],
		LeftShoulder: [35, 0, -78],
		LeftElbow: [15, 0, 0],
		RightHip: [30, 0, 12],
		RightKnee: [-45, 0, 0],
		LeftHip: [-20, 0, -12],
		LeftKnee: [-35, 0, 0],
		RightAnkle: [14, 0, 0],
		LeftAnkle: [34, 0, 0],
	},
	// Tusukan: bahu kanan maju, lengan + bilah lurus datar ke depan setinggi bahu
	thrust: {
		Root: [0, 0, 0, -0.3],
		Waist: [-8, 16, 0],
		Neck: [5, -12, 0],
		RightShoulder: [98, 0, 16],
		RightElbow: [0, 0, 0],
		RightWrist: [-90, 0, 0],
		LeftShoulder: [20, 0, -80],
		RightHip: [40, 0, 0],
		RightKnee: [-35, 0, 0],
		LeftHip: [-30, 0, 0],
	},
	// Prajurit siaga di barisan: tombak tegak di tangan kanan
	attention: {
		Neck: [-3, 0, 0],
		RightShoulder: [18, 0, 8],
		RightElbow: [82, 0, 0],
		RightWrist: [-5, 0, 0],
		LeftShoulder: [0, 0, -4],
	},
	// Prajurit lari menyerbu: tombak dipegang rendah ke depan
	charge: {
		Root: [0, 0, 0, -0.2],
		Waist: [-18, -10, 0],
		Neck: [12, 8, 0],
		RightShoulder: [55, 0, 10],
		RightElbow: [30, 0, 0],
		RightWrist: [-75, 0, 0],
		LeftShoulder: [60, 0, -20],
		LeftElbow: [40, 0, 0],
	},
	crouch: {
		Root: [0, 0, 0, -0.8],
		Waist: [-30, 0, 0],
		Neck: [22, 0, 0],
		RightShoulder: [-10, 0, 25],
		RightWrist: [40, 0, 0],
		LeftShoulder: [-30, 0, -20],
		RightHip: [70, 0, 0],
		RightKnee: [-100, 0, 0],
		LeftHip: [70, 0, 0],
		LeftKnee: [-100, 0, 0],
		RightAnkle: [30, 0, 0],
		LeftAnkle: [30, 0, 0],
	},
	// Melesat ke atas: lutut ditekuk, pedang terseret di belakang
	leapTuck: {
		Waist: [-15, 0, 0],
		Neck: [15, 0, 0],
		RightShoulder: [-40, 0, 35],
		RightElbow: [10, 0, 0],
		RightWrist: [-40, 0, 0],
		LeftShoulder: [-30, 0, -35],
		RightHip: [70, 0, 0],
		RightKnee: [-95, 0, 0],
		LeftHip: [35, 0, 0],
		LeftKnee: [-60, 0, 0],
		RightAnkle: [-30, 0, 0],
		LeftAnkle: [-30, 0, 0],
	},
	// Awalan tebasan raksasa di udara: pedang diangkat tinggi di atas kepala, badan melengkung
	overhead: {
		Waist: [14, 12, 0],
		Neck: [12, -8, 0],
		RightShoulder: [168, 0, 12],
		RightElbow: [28, 0, 0],
		RightWrist: [-15, 0, 0],
		LeftShoulder: [70, 0, -45],
		LeftElbow: [30, 0, 0],
		RightHip: [-22, 0, 0],
		RightKnee: [-45, 0, 0],
		LeftHip: [40, 0, 0],
		LeftKnee: [-75, 0, 0],
		RightAnkle: [-25, 0, 0],
		LeftAnkle: [-20, 0, 0],
	},
	// Tebasan raksasa ke bawah: badan membungkuk penuh, pedang lewat ke bawah depan
	downSlash: {
		Waist: [-38, -12, 0],
		Neck: [26, 6, 0],
		RightShoulder: [45, 0, 12],
		RightElbow: [6, 0, 0],
		RightWrist: [-55, 0, 0],
		LeftShoulder: [-25, 0, -50],
		LeftElbow: [20, 0, 0],
		RightHip: [-30, 0, 0],
		RightKnee: [-30, 0, 0],
		LeftHip: [55, 0, 0],
		LeftKnee: [-65, 0, 0],
		RightAnkle: [-30, 0, 0],
		LeftAnkle: [-15, 0, 0],
	},
	// Melayang tenang di udara: kaki menggantung, pedang turun di samping
	hover: {
		Waist: [-4, -8, 0],
		Neck: [0, 6, 0],
		RightShoulder: [12, 0, 18],
		RightElbow: [12, 0, 0],
		RightWrist: [-70, 0, 0],
		LeftShoulder: [8, 0, -14],
		LeftElbow: [18, 0, 0],
		RightHip: [8, 0, 4],
		RightKnee: [-18, 0, 0],
		LeftHip: [-4, 0, -4],
		LeftKnee: [-26, 0, 0],
		RightAnkle: [-35, 0, 0],
		LeftAnkle: [-35, 0, 0],
	},
	// Sosok diam: dua jari ke depan, badan tegak
	twoFinger: {
		RightShoulder: [88, 0, 0],
		RightElbow: [8, 0, 0],
	},
	handsBehind: {
		Neck: [-4, 0, 0],
		RightShoulder: [-20, 0, 30],
		RightElbow: [70, 0, 0],
		LeftShoulder: [-20, 0, -30],
		LeftElbow: [70, 0, 0],
	},
	// Kena hantaman dan terlempar ke belakang
	fallBack: {
		Waist: [35, 0, 0],
		Neck: [-25, 0, 0],
		RightShoulder: [60, 0, 80],
		LeftShoulder: [60, 0, -80],
		RightHip: [45, 0, 0],
		RightKnee: [-55, 0, 0],
		LeftHip: [25, 0, 0],
		LeftKnee: [-20, 0, 0],
	},
	// Prajurit terhempas: badan melengkung, tangan-kaki terlempar
	hitFly: {
		Waist: [30, 0, 15],
		Neck: [25, 0, 0],
		RightShoulder: [130, 0, 60],
		RightElbow: [30, 0, 0],
		LeftShoulder: [130, 0, -60],
		LeftElbow: [30, 0, 0],
		RightHip: [35, 0, 10],
		RightKnee: [-50, 0, 0],
		LeftHip: [-10, 0, -10],
		LeftKnee: [-20, 0, 0],
	},
	// Mendarat keras: satu lutut + tangan kiri ke tanah
	landing: {
		Root: [0, 0, 0, -1.04],
		Waist: [-34, 0, 0],
		Neck: [18, 0, 0],
		RightShoulder: [-10, 0, 35],
		RightWrist: [-60, 0, 0],
		LeftShoulder: [40, 0, -18],
		LeftElbow: [10, 0, 0],
		RightHip: [85, 0, 6],
		RightKnee: [-115, 0, 0],
		LeftHip: [10, 0, -16],
		LeftKnee: [-100, 0, 0],
		RightAnkle: [30, 0, 0],
		LeftAnkle: [-70, 0, 0],
	},
	// Berlutut kalah: badan bungkuk, kepala tertunduk
	kneel: {
		Root: [0, 0, 0, -0.99],
		Waist: [-22, 0, 0],
		Neck: [-24, 0, 0],
		RightShoulder: [25, 0, 10],
		RightWrist: [-70, 0, 0],
		LeftShoulder: [30, 0, -10],
		RightHip: [90, 0, 0],
		RightKnee: [-90, 0, 0],
		LeftHip: [0, 0, 0],
		LeftKnee: [-90, 0, 0],
		LeftAnkle: [-75, 0, 0],
	},
	// Masih berlutut, dongak natap sosok di atas
	kneelLookUp: {
		Root: [0, 0, 0, -0.99],
		Waist: [6, 0, 0],
		Neck: [34, 0, 0],
		RightShoulder: [25, 0, 10],
		RightWrist: [-70, 0, 0],
		LeftShoulder: [10, 0, -10],
		RightHip: [90, 0, 0],
		RightKnee: [-90, 0, 0],
		LeftHip: [0, 0, 0],
		LeftKnee: [-90, 0, 0],
		LeftAnkle: [-75, 0, 0],
	},
	pointForward: {
		Waist: [4, 0, 0],
		Neck: [-6, 0, 0],
		RightShoulder: [90, 0, 0],
		LeftShoulder: [-10, 0, -10],
	},
};

/** Satu sendi jadi 4 angka [rx, ry, rz (derajat), dy (stud)]. Sendi yang gak disebut = 0. */
export function jointVec(rot: JointRot | undefined): [number, number, number, number] {
	if (!rot) return [0, 0, 0, 0];
	const dy = rot.size() > 3 ? (rot as [number, number, number, number])[3] : 0;
	return [rot[0], rot[1], rot[2], dy];
}

/** Rotasi sendi (derajat) + geser turun jadi CFrame. */
export function jointCFrame(rx: number, ry: number, rz: number, dy: number): CFrame {
	return new CFrame(0, dy, 0).mul(CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz)));
}
