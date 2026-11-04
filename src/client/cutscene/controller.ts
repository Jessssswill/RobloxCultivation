// Penghubung client ke server: server nyuruh "play", client lapor "done". Tonton ulang lewat requestReplay.

import { ReplicatedStorage } from "@rbxts/services";
import { getCutscene, REMOTE_NAME } from "shared/cutscene/registry";
import { CutsceneRun } from "./runtime";

let remote: RemoteEvent | undefined;
let running: CutsceneRun | undefined;

export function isPlaying() {
	return running !== undefined;
}

/** Minta tonton ulang (menu Kuil Ingatan). Server cuma ngizinin cutscene yang udah pernah ditonton. */
export function requestReplay(id: string) {
	remote?.FireServer("replay", id);
}

export function init() {
	const r = ReplicatedStorage.WaitForChild(REMOTE_NAME) as RemoteEvent;
	remote = r;
	r.OnClientEvent.Connect((action: unknown, id: unknown) => {
		if (action !== "play" || !typeIs(id, "string")) return;
		const def = getCutscene(id);
		if (!def || running) {
			r.FireServer("done", id, true);
			return;
		}
		const run = new CutsceneRun(def, (skipped) => {
			running = undefined;
			r.FireServer("done", id, skipped);
		});
		running = run;
		run.start();
	});
}
