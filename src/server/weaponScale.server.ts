// Tiap kali pemain megang senjata, senjata diskalain sesuai tinggi avatarnya.
import { Players } from "@rbxts/services";
import { factorFor, scaleTool } from "shared/weaponScale";

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

Players.PlayerAdded.Connect(onPlayer);
for (const player of Players.GetPlayers()) onPlayer(player);
