// Semua cutscene yang ada di game. Urutan = urutan di menu tonton ulang (Kuil Ingatan).
// Daftar lengkap 14 cutscene ada di Notion "Alur Game Draft 1.0", bagian Cutscene animasi.

import { CutsceneDef } from "./types";
import { C01_PROLOG } from "./scenes/c01_prolog";

export const CUTSCENES: CutsceneDef[] = [C01_PROLOG];

export function getCutscene(id: string): CutsceneDef | undefined {
	return CUTSCENES.find((c) => c.id === id);
}

export const REMOTE_NAME = "CutsceneRemote";
/** Atribut pemain: id cutscene yang udah ditonton, dipisah koma. Nanti ikut disimpan ke DataStore. */
export const SEEN_ATTR = "SeenCutscenes";
/** Atribut karakter selama cutscene jalan (dipakai sistem lain buat skip AI, combat, dll). */
export const ACTIVE_ATTR = "InCutscene";
