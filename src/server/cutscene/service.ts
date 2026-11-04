// Server cutscene: nyuruh client muter, pasang tameng selama nonton, catat yang udah ditonton,
// ngizinin tonton ulang. Script Luau lama bisa pakai ServerStorage.PlayCutscene (BindableEvent).

import { Players, ReplicatedStorage, RunService } from "@rbxts/services";
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

/** Rig polos R15 buat aktor yang belum punya model sendiri (pasukan, sosok misterius, Bai Wuji sementara). */
export function ensureRigs() {
	let folder = ReplicatedStorage.FindFirstChild("CutsceneRigs");
	if (!folder) {
		folder = new Instance("Folder");
		folder.Name = "CutsceneRigs";
		folder.Parent = ReplicatedStorage;
	}
	if (folder.FindFirstChild("Mannequin")) return;
	const desc = new Instance("HumanoidDescription");
	const grey = Color3.fromRGB(190, 190, 195);
	desc.HeadColor = grey;
	desc.TorsoColor = grey;
	desc.LeftArmColor = grey;
	desc.RightArmColor = grey;
	desc.LeftLegColor = grey;
	desc.RightLegColor = grey;
	const [ok, model] = pcall(() => Players.CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15));
	if (!ok) {
		warn(`[Cutscene] Gagal bikin Mannequin: ${model}`);
		return;
	}
	for (const d of model.GetDescendants()) if (d.IsA("LuaSourceContainer")) d.Destroy();
	model.Name = "Mannequin";
	model.Parent = folder;
}
