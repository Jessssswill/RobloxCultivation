// Pose keyframe buat aktor cutscene, tanpa upload animasi. Tiap pose = rotasi sendi R15 (derajat X, Y, Z)
// yang dikaliin ke C0 Motor6D aslinya, plus opsional geser badan turun (dy, khusus sendi Root).
// Sendi yang gak disebut balik ke netral. Arah: +X = angkat ke depan, +Y = putar ke kiri, +Z = ke kanan badan.
// Nanti kalau animasi asli udah di-upload (izin will), pakai event "anim" aja.

export type JointRot = [number, number, number] | [number, number, number, number];
export type Pose = Partial<Record<string, JointRot>>;

export const POSES: Record<string, Pose> = {
	idle: {},
	// Siaga jian: pedang serong ke depan, kuda-kuda rendah
	guard: {
		Root: [0, 0, 0, -0.25],
		Waist: [0, -20, 0],
		Neck: [0, 15, 0],
		RightShoulder: [65, 0, 15],
		RightElbow: [35, 0, 0],
		RightWrist: [-55, 0, 0],
		LeftShoulder: [35, 0, -25],
		LeftElbow: [70, 0, 0],
		RightHip: [25, 0, 8],
		RightKnee: [-30, 0, 0],
		LeftHip: [-12, 0, -8],
		LeftKnee: [-25, 0, 0],
	},
	// Tebasan kiri ke kanan: awalan lengan nyilang ke kiri
	slashWindup: {
		Root: [0, 0, 0, -0.3],
		Waist: [0, 45, 0],
		Neck: [0, -30, 0],
		RightShoulder: [100, 0, -55],
		RightElbow: [55, 0, 0],
		RightWrist: [-40, 0, 0],
		LeftShoulder: [25, 0, -35],
		RightHip: [15, 0, 0],
		LeftKnee: [-30, 0, 0],
	},
	slashFollow: {
		Root: [0, 0, 0, -0.45],
		Waist: [-8, -55, 0],
		Neck: [0, 35, 0],
		RightShoulder: [85, 0, 75],
		RightElbow: [5, 0, 0],
		RightWrist: [-30, 0, 0],
		LeftShoulder: [15, 0, -70],
		RightHip: [35, 0, 0],
		RightKnee: [-45, 0, 0],
		LeftHip: [-25, 0, 0],
	},
	thrust: {
		Root: [0, 0, 0, -0.3],
		Waist: [12, -15, 0],
		RightShoulder: [90, 0, 0],
		RightElbow: [0, 0, 0],
		RightWrist: [-90, 0, 0],
		LeftShoulder: [20, 0, -80],
		RightHip: [40, 0, 0],
		RightKnee: [-35, 0, 0],
		LeftHip: [-30, 0, 0],
	},
	crouch: {
		Root: [0, 0, 0, -1],
		Waist: [30, 0, 0],
		Neck: [-20, 0, 0],
		RightShoulder: [-30, 0, 20],
		RightWrist: [-60, 0, 0],
		LeftShoulder: [-30, 0, -20],
		RightHip: [70, 0, 0],
		RightKnee: [-100, 0, 0],
		LeftHip: [70, 0, 0],
		LeftKnee: [-100, 0, 0],
	},
	// Sosok diam: dua jari ke depan, badan tegak
	twoFinger: {
		RightShoulder: [88, 0, 0],
		RightElbow: [8, 0, 0],
	},
	handsBehind: {
		RightShoulder: [-20, 0, 30],
		RightElbow: [70, 0, 0],
		LeftShoulder: [-20, 0, -30],
		LeftElbow: [70, 0, 0],
	},
	fallBack: {
		Waist: [-35, 0, 0],
		Neck: [-30, 0, 0],
		RightShoulder: [60, 0, 80],
		LeftShoulder: [60, 0, -80],
		RightHip: [45, 0, 0],
		RightKnee: [-55, 0, 0],
		LeftHip: [25, 0, 0],
		LeftKnee: [-20, 0, 0],
	},
	kneel: {
		Root: [0, 0, 0, -1.5],
		Waist: [25, 0, 0],
		Neck: [20, 0, 0],
		RightShoulder: [25, 0, 10],
		RightWrist: [-70, 0, 0],
		LeftShoulder: [30, 0, -10],
		RightHip: [90, 0, 0],
		RightKnee: [-90, 0, 0],
		LeftHip: [0, 0, 0],
		LeftKnee: [-90, 0, 0],
	},
	kneelLookUp: {
		Root: [0, 0, 0, -1.5],
		Waist: [-5, 0, 0],
		Neck: [-35, 0, 0],
		RightShoulder: [25, 0, 10],
		RightWrist: [-70, 0, 0],
		LeftShoulder: [10, 0, -10],
		RightHip: [90, 0, 0],
		RightKnee: [-90, 0, 0],
		LeftHip: [0, 0, 0],
		LeftKnee: [-90, 0, 0],
	},
	pointForward: {
		RightShoulder: [90, 0, 0],
		LeftShoulder: [-10, 0, -10],
	},
};

/** Breaks a joint entry into its rotation CFrame (offset dy is applied to Root only). */
export function jointCFrame(rot: JointRot | undefined): CFrame {
	if (!rot) return new CFrame();
	const dy = rot.size() > 3 ? (rot as [number, number, number, number])[3] : 0;
	return new CFrame(0, dy, 0).mul(CFrame.Angles(math.rad(rot[0]), math.rad(rot[1]), math.rad(rot[2])));
}
