// Server cutscene: nyuruh client muter, pasang tameng selama nonton, catat yang udah ditonton,
// ngizinin tonton ulang. Script Luau lama bisa pakai ServerStorage.PlayCutscene (BindableEvent).

import { Players, ReplicatedStorage, RunService, ServerStorage } from "@rbxts/services";
import { ACTIVE_ATTR, getCutscene, REMOTE_NAME, SEEN_ATTR } from "shared/cutscene/registry";

const remote = new Instance("RemoteEvent");
remote.Name = REMOTE_NAME;
remote.Parent = ReplicatedStorage;

interface Active {
	id: string;
	token: number;
	shield?: ForceField;
	done?: (skipped: boolean) => void;
}

const active = new Map<Player, Active>();
const lastReplay = new Map<Player, number>();
let tokens = 0;

/** Dipanggil tiap cutscene selesai (buat event, quest, DataStore nanti). */
export const finished = new Instance("BindableEvent");

function seenList(player: Player): string[] {
	const raw = player.GetAttribute(SEEN_ATTR);
	return typeIs(raw, "string") && raw !== "" ? raw.split(",") : [];
}

export function hasSeen(player: Player, id: string) {
	return seenList(player).includes(id);
}

function markSeen(player: Player, id: string) {
	const list = seenList(player);
	if (list.includes(id)) return;
	list.push(id);
	player.SetAttribute(SEEN_ATTR, list.join(","));
}

function finish(player: Player, token: number, skipped: boolean) {
	const a = active.get(player);
	if (!a || a.token !== token) return;
	active.delete(player);
	a.shield?.Destroy();
	player.Character?.SetAttribute(ACTIVE_ATTR, undefined);
	markSeen(player, a.id);
	a.done?.(skipped);
	finished.Fire(player, a.id, skipped);
}

export function isWatching(player: Player) {
	return active.has(player);
}

/** Putar cutscene buat satu pemain. done(skipped) dipanggil pas selesai, di-skip, atau kelamaan. */
export function playCutscene(player: Player, id: string, done?: (skipped: boolean) => void): boolean {
	const def = getCutscene(id);
	if (!def || active.has(player) || player.Parent === undefined) return false;
	tokens += 1;
	const token = tokens;
	const char = player.Character;
	let shield: ForceField | undefined;
	if (char) {
		// Gak bisa diserang selama nonton (TakeDamage ngehormatin ForceField)
		shield = new Instance("ForceField");
		shield.Name = "CutsceneShield";
		shield.Visible = false;
		shield.Parent = char;
		char.SetAttribute(ACTIVE_ATTR, true);
	}
	active.set(player, { id, token, shield, done });
	remote.FireClient(player, "play", id);
	// Slow-mo bikin durasi asli lebih panjang dari timeline, kasih jeda aman
	task.delay(def.length * 1.5 + 20, () => finish(player, token, true));
	return true;
}

remote.OnServerEvent.Connect((player, action, id, skipped) => {
	if (!typeIs(action, "string") || !typeIs(id, "string")) return;
	if (action === "done") {
		const a = active.get(player);
		if (a && a.id === id) finish(player, a.token, skipped === true);
	} else if (action === "replay") {
		const now = os.clock();
		if (now - (lastReplay.get(player) ?? -math.huge) < 3) return;
		lastReplay.set(player, now);
		if (hasSeen(player, id) || RunService.IsStudio()) playCutscene(player, id);
	}
});

Players.PlayerRemoving.Connect((player) => {
	active.delete(player);
	lastReplay.delete(player);
});

// Rig tokoh cutscene, dirakit dari item katalog Roblox lewat HumanoidDescription (gak upload, gak beli:
// NPC boleh pakai item katalog apa aja). Dipilih 4 Nov 2026, tinggal ganti id kalau will mau look lain.
const SKIN = Color3.fromRGB(234, 200, 170);
const GOLD_SKIN = Color3.fromRGB(222, 178, 92);
const VOID = Color3.fromRGB(16, 16, 20);
const A = Enum.AccessoryType;

type RigidSlot = "HairAccessory" | "HatAccessory" | "BackAccessory" | "NeckAccessory" | "ShouldersAccessory" | "WaistAccessory";

interface RigSpec {
	skin: Color3;
	/** Kepala dinamis (wajah). Kosong = kepala standar. */
	head?: number;
	rigid?: Partial<Record<RigidSlot, string>>;
	/** Baju berlapis, urutan = dalam ke luar. */
	layered?: Array<[number, Enum.AccessoryType]>;
	height?: number;
	width?: number;
	/** Badan + baju berlapis dicat satu warna (Sosok Diam). Aksesori kaku (aura) dibiarin. */
	paint?: Color3;
	/** Kepala polos tanpa wajah, kulit logam emas (prajurit langit). */
	faceless?: boolean;
}

const RIGS: Record<string, RigSpec> = {
	// Pendekar jubah putih: rambut kultivator hitam, tusuk konde emas-giok, kalung giok, jubah + hanfu lengan lebar, jubah luar emas-putih
	BaiWuji: {
		skin: SKIN,
		head: 78798888652850, // Serious Anime Man Face
		rigid: {
			HairAccessory: "11639642608", // Cultivator's Hair - Black
			HatAccessory: "102937532085683", // Traditional Chinese Hairpins in Gold & Jade
			NeckAccessory: "140060761954341", // Jade Chinese Necklace
			BackAccessory: "89022123208501", // Oracle Ethereal Gaian Cloak Cape | Gold White
			WaistAccessory: "134462104424806", // chinese coins lucky charm tassel
		},
		layered: [
			[12388422808, A.DressSkirt], // White Cultivator's Robes
			[91069499134710, A.Jacket], // Mist White Song dynasty Hanfu Long Sleeves
		],
		height: 1.05,
	},
	// Jenderal langit: zirah putih-emas, bahu emas, jubah emas, lingkaran matahari emas di kepala, badan lebih besar
	Commander: {
		skin: SKIN,
		head: 128378133255219, // Sleek manhwa serious business
		rigid: {
			HairAccessory: "88942801375060", // Traditional Chinese Male General Hairstyles
			HatAccessory: "137018265353053", // Golden Sun Halo
			ShouldersAccessory: "14728733203,14715952563", // Gold Overlord Armor Right + Gold Armor Left
			BackAccessory: "76488412041177", // Gold Cape
		},
		layered: [
			[107218828660621, A.Shirt], // Qin Shi Huang
			[81156597216720, A.Pants], // Chinese Warrior Leggings - Gold
			[112998996776709, A.Jacket], // White Royal Sun Armor
		],
		height: 1.25,
		width: 1.1,
	},
	// Prajurit langit: konstruk emas tanpa wajah, helm, bahu emas, zirah Qin
	HeavenSoldier: {
		skin: GOLD_SKIN,
		faceless: true,
		rigid: {
			HatAccessory: "84748693465124", // Chuyin Helmet
			ShouldersAccessory: "14728733203,14715952563",
		},
		layered: [
			[128105502437935, A.Shirt], // Qin Shi Huang
			[81156597216720, A.Pants],
		],
		height: 1.1,
	},
	// Sosok Diam: jubah bertudung hitam pekat + aura hampa, wajah gak kelihatan
	Figure: {
		skin: VOID,
		paint: VOID,
		rigid: { BackAccessory: "113122316962402" }, // Black Void Glow Aura
		layered: [[12864558239, A.Jacket]], // Hooded Knight Cloak - Black
		height: 1.08,
	},
};

function buildRig(name: string, spec: RigSpec): Model | undefined {
	const d = new Instance("HumanoidDescription");
	d.HeadColor = spec.skin;
	d.TorsoColor = spec.skin;
	d.LeftArmColor = spec.skin;
	d.RightArmColor = spec.skin;
	d.LeftLegColor = spec.skin;
	d.RightLegColor = spec.skin;
	if (spec.head !== undefined) d.Head = spec.head;
	if (spec.rigid) for (const [slot, ids] of pairs(spec.rigid)) d[slot] = ids;
	d.HeightScale = spec.height ?? 1;
	d.WidthScale = spec.width ?? 1;
	d.DepthScale = spec.width ?? 1;
	if (spec.layered) {
		const list = d.GetAccessories(true);
		spec.layered.forEach(([id, kind], i) => list.push({ AssetId: id, AccessoryType: kind, Order: i + 1, IsLayered: true }));
		d.SetAccessories(list, true);
	}
	const [ok, model] = pcall(() => Players.CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15));
	if (!ok) {
		warn(`[Cutscene] Gagal bikin rig ${name}: ${model}`);
		return undefined;
	}
	for (const x of model.GetDescendants()) if (x.IsA("LuaSourceContainer")) x.Destroy();
	const head = model.FindFirstChild("Head");
	if (spec.faceless || spec.paint) for (const x of head?.GetChildren() ?? []) if (x.IsA("Decal")) x.Destroy();
	for (const x of model.GetDescendants()) {
		if (!x.IsA("BasePart") || x.Name === "HumanoidRootPart") continue;
		const body = x.Parent === model;
		if (spec.faceless && body) {
			x.Color = spec.skin;
			x.Material = Enum.Material.Metal;
			// Kepala standar sekarang kepala dinamis: wajahnya ada di TextureID, bukan Decal
			if (x.Name === "Head" && x.IsA("MeshPart")) pcall(() => (x.TextureID = ""));
		}
		const color = spec.paint;
		if (color && (body || x.FindFirstChildOfClass("WrapLayer"))) {
			x.FindFirstChildOfClass("SurfaceAppearance")?.Destroy();
			x.Color = color;
			x.Material = Enum.Material.SmoothPlastic;
			if (x.IsA("MeshPart")) pcall(() => (x.TextureID = ""));
		}
	}
	model.Name = name;
	return model;
}

/**
 * Pedang mesh buat aktor cutscene, disalin dari senjata yang udah ada di place (ServerStorage.Weapons, gak upload apa-apa).
 * Script, remote, dan efek bawaan Tool dibuang, sisanya jadi Model polos dengan PrimaryPart = Handle.
 */
const SWORDS: Record<string, string> = {
	BaiSword: "Spirit Sword",
};

function copyWeapon(name: string, from: string): Model | undefined {
	const tool = ServerStorage.FindFirstChild("Weapons")?.FindFirstChild(from);
	if (!tool) {
		warn(`[Cutscene] Senjata ${from} gak ada di ServerStorage.Weapons, aktor pakai pedang part`);
		return undefined;
	}
	// Clone Tool-nya utuh dulu baru dipindah isinya: kalau anaknya di-clone satu-satu, las (Weld) bilah masih nunjuk
	// ke Handle asli di ServerStorage (gak ada di client), bilahnya lepas dan jatuh
	const copy = tool.Clone();
	const model = new Instance("Model");
	model.Name = name;
	for (const child of copy.GetChildren()) {
		if (child.IsA("LuaSourceContainer") || child.IsA("RemoteEvent") || child.IsA("RemoteFunction") || child.IsA("BindableEvent")) child.Destroy();
		else child.Parent = model;
	}
	copy.Destroy();
	for (const d of model.GetDescendants()) if (d.IsA("LuaSourceContainer")) d.Destroy();
	const handle = model.FindFirstChild("Handle");
	if (!handle || !handle.IsA("BasePart")) {
		model.Destroy();
		return undefined;
	}
	model.PrimaryPart = handle;
	return model;
}

/** Rig cutscene: Mannequin polos (cadangan) + tokoh dari katalog. Dipanggil sekali pas server nyala. */
export function ensureRigs() {
	let folder = ReplicatedStorage.FindFirstChild("CutsceneRigs");
	if (!folder) {
		folder = new Instance("Folder");
		folder.Name = "CutsceneRigs";
		folder.Parent = ReplicatedStorage;
	}
	if (!folder.FindFirstChild("Mannequin")) {
		const grey = Color3.fromRGB(190, 190, 195);
		const mannequin = buildRig("Mannequin", { skin: grey });
		if (mannequin) mannequin.Parent = folder;
	}
	for (const [name, from] of pairs(SWORDS)) {
		if (folder.FindFirstChild(name)) continue;
		const sword = copyWeapon(name, from);
		if (sword) sword.Parent = folder;
	}
	// Urutan tetap: tokoh utama duluan biar siap paling cepat
	for (const name of ["BaiWuji", "Figure", "Commander", "HeavenSoldier"]) {
		const spec = RIGS[name];
		if (spec === undefined || folder.FindFirstChild(name)) continue;
		const rig = buildRig(name, spec);
		if (rig) rig.Parent = folder;
	}
}
