// Nyalain sistem cutscene di server + jembatan buat script Luau + cara tes di Studio.
//
// Dari Luau:  game.ServerStorage.PlayCutscene:Fire(player, "c01_prolog")
//             game.ServerStorage.CutsceneFinished.Event:Connect(function(player, id, skipped) ... end)
// Tes di Studio (Play): ketik "!cs 1" atau "!cs c01_prolog" di chat,
//             atau command bar server: workspace:SetAttribute("TestCutscene", "c01_prolog")

import { Players, RunService, ServerStorage, Workspace } from "@rbxts/services";
import { CUTSCENES } from "shared/cutscene/registry";
import { ensureRigs, finished, playCutscene } from "server/cutscene/service";

task.spawn(ensureRigs);

const play = new Instance("BindableEvent");
play.Name = "PlayCutscene";
play.Event.Connect((player: unknown, id: unknown) => {
	if (typeIs(player, "Instance") && player.IsA("Player") && typeIs(id, "string")) playCutscene(player, id);
});
play.Parent = ServerStorage;
finished.Name = "CutsceneFinished";
finished.Parent = ServerStorage;

if (RunService.IsStudio()) {
	const resolve = (arg: string) => {
		const n = tonumber(arg);
		return n !== undefined ? CUTSCENES[n - 1]?.id : arg !== "" ? arg : CUTSCENES[0]?.id;
	};
	const onPlayer = (player: Player) => {
		player.Chatted.Connect((msg) => {
			const [arg] = msg.match("^!cs%s*(%S*)");
			if (arg === undefined) return;
			const id = resolve(tostring(arg));
			if (id !== undefined) playCutscene(player, id);
		});
	};
	Players.PlayerAdded.Connect(onPlayer);
	for (const p of Players.GetPlayers()) onPlayer(p);

	Workspace.GetAttributeChangedSignal("TestCutscene").Connect(() => {
		const raw = Workspace.GetAttribute("TestCutscene");
		if (!typeIs(raw, "string") || raw === "") return;
		const id = resolve(raw);
		if (id !== undefined) for (const p of Players.GetPlayers()) playCutscene(p, id);
		Workspace.SetAttribute("TestCutscene", undefined);
	});
}
