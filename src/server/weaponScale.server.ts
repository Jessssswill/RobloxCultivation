// Tiap kali pemain megang senjata, senjata diskalain sesuai tinggi avatarnya.
// DIMATIIN (2026-11-04, will: "urus semuanya"): skala senjata diurus Luau ServerScriptService.WeaponScaleServer,
// yang ikut BaseScale tiap pedang (ukuran BIG 20 Okt). Kalau dua-duanya jalan lewat `rojo serve`, pedang diskalain
// dua kali dan ukuran BIG-nya hilang. Hidupin lagi (ENABLED = true) cuma kalau WeaponScaleServer udah dihapus,
// dan tambahin BaseScale dulu di sini.
import { Players } from "@rbxts/services";
import { factorFor, scaleTool } from "shared/weaponScale";

const ENABLED: boolean = false;

function onCharacter(character: Model) {
	character.ChildAdded.Connect((child) => {
		if (child.IsA("Tool") && child.FindFirstChild("Handle")) {
			scaleTool(child, factorFor(character));
		}
	});
}

function onPlayer(player: Player) {
	player.CharacterAdded.Connect(onCharacter);
	if (player.Character) onCharacter(player.Character);
}

if (ENABLED) {
	Players.PlayerAdded.Connect(onPlayer);
	for (const player of Players.GetPlayers()) onPlayer(player);
}
