# Qi Cultivation (roblox-ts + Rojo)

Project script game Qi Cultivation. Kode baru ditulis pakai TypeScript (roblox-ts) di `src/`, terus Rojo nyambungin hasilnya ke Studio. Script Luau lama yang udah jalan disimpan apa adanya di `luau/` dan ikut disambungin juga, nanti dipindah ke TypeScript satu per satu.

## Isi folder

| Folder | Isi | Masuk ke Studio sebagai |
|---|---|---|
| `src/shared` | Modul TypeScript yang dipakai server dan client | `ReplicatedStorage.TS` |
| `src/server` | Script server TypeScript (`*.server.ts`) | `ServerScriptService.TS` |
| `src/client` | Script client TypeScript (`*.client.ts`) | `StarterPlayer.StarterPlayerScripts.TS` |
| `luau/ServerScriptService` | Semua script Luau di ServerScriptService (17) | lokasi aslinya, nama sama |
| `luau/StarterPlayerScripts` | Semua LocalScript di StarterPlayerScripts (19) | lokasi aslinya, nama sama |
| `luau/ReplicatedStorage` | `WeaponScale` dan folder `Skill` (3 modul) | lokasi aslinya, nama sama |
| `luau/dalam_model` | Script yang nempel di dalam Tool/model (senjata, monster, NPC, backup) | belum disambung |
| `luau/shared` | Rencana modul `WeaponCombo` gabungan | `ReplicatedStorage.Luau` |

Daftar lengkap 81 script, lokasi Studio, dan filenya ada di `luau/DAFTAR SCRIPT.md`.

Tiap script Luau dipetakan satu per satu di `default.project.json` ke path aslinya, jadi `require` dan `WaitForChild` yang udah ada tetap jalan. Semua node pakai `$ignoreUnknownInstances`, jadi anak di dalam script (misalnya bola di `Skill.Disintegration`) dan semua isi place lain (map, model, UI) nggak disentuh Rojo. `MonsterSpawner` tetap mati (`Disabled`) lewat `MonsterSpawner.meta.json`.

## Status (27 Okt 2026)

- Semua 81 script udah ditarik dari place (Download a Copy, 27 Okt). 39 script yang langsung ada di service udah disambung Rojo, isinya dicek sama persis dengan di Studio.
- 42 script di dalam Tool/model isinya cuma 12 versi beda (contoh: `WeaponCombo` disalin 12x, `ComboServer` 12x dalam 2 versi, `MonsterAI` 6 monster pakai yang sama). Disimpan sekali per versi di `luau/dalam_model/`. Belum disambung karena Tool/model-nya sendiri diurus di Studio. Langkah berikutnya: ganti salinan itu jadi script kecil yang `require` satu modul.
- `src/server/weaponScale.server.ts` itu versi TS dari `WeaponScaleServer`. Kalau dua-duanya jalan, skala dipasang dua kali. Pilih salah satu sebelum `npm run watch`.

## Cara nyambungin ke Studio (di laptop)

**Versi cepat, cuma script Luau (nggak butuh Node.js):** jalanin `rojo serve luau.project.json`, terus Connect dari plugin Rojo di Studio. File `luau.project.json` sama dengan `default.project.json` tapi tanpa bagian TypeScript.

**Versi lengkap (Luau + TypeScript):**

Butuh Node.js (LTS) dan Rojo 7.7.1 (udah ada di `C:\Users\Shen\Project\ROBLOX\Rojo`).

1. Buka terminal di folder project ini, jalanin `npm install` sekali.
2. Jalanin `npm run watch`. Biarin kebuka, tiap file `src/` disimpan langsung di-compile ke `out/`.
3. Di terminal lain jalanin `rojo serve`.
4. Di Studio buka plugin Rojo, klik Connect.

**Penting soal Connect:** Rojo bakal nimpa 39 script di Studio yang namanya sama dengan isi dari folder `luau/`. Nggak ada yang jalan dua kali, jadi nggak perlu hapus apa-apa dulu. Tapi habis Connect, script itu diedit di file (VS Code), bukan di Studio, karena editan di Studio bakal ketimpa.

## Perintah

| Perintah | Fungsi |
|---|---|
| `npm run build` | Compile TypeScript sekali |
| `npm run watch` | Compile otomatis tiap file disimpan |
| `rojo serve` | Nyambungin project ke Studio |
| `rojo build -o test.rbxlx` | Bikin place percobaan dari project (buat ngecek struktur) |

## Sistem cutscene (4 Nov 2026)

Cutscene sinematik ala donghua, semua bisa di-skip (tahan Space / Enter / tombol B / tahan tombol di layar). Kode di `src/shared/cutscene`, `src/client/cutscene`, `src/server/cutscene`.

- **Satu cutscene = satu file data** di `src/shared/cutscene/scenes/`, didaftarin di `registry.ts`. Isinya kunci kamera (spline halus, bisa ngikutin aktor), aktor, dan daftar event (subtitle, kartu nama, pose, gerak, VFX, impact, slow-mo, suara).
- **Animasi tanpa upload:** aktor itu salinan rig R15, digerakin lewat C0 Motor6D dari pose di `poses.ts`. Kalau nanti animasi asli udah di-upload (izin will), pakai event `anim`.
- **Rasa donghua:** impact frame (hitam-putih sekejap) + hitstop + garis kecepatan, slow-mo, afterimage waktu gerak cepat, kartu nama tokoh, DOF, grading warna, guncangan kamera.
- **Ringan di HP:** `quality.ts` otomatis pindah ke mode ringan di HP atau grafik rendah: tanpa DOF, partikel 40%, afterimage maks 3, set lebih sedikit part dan lampu, awan gak transparan.
- **Server:** pemain dapat ForceField tak terlihat + atribut karakter `InCutscene` selama nonton. Yang udah ditonton dicatat di atribut pemain `SeenCutscenes` (nanti ikut DataStore). Tonton ulang lewat `requestReplay(id)` di client, cuma buat yang udah pernah ditonton.
- **Dari Luau:** `game.ServerStorage.PlayCutscene:Fire(player, "c01_prolog")`, dan `game.ServerStorage.CutsceneFinished.Event` buat lanjut cerita.
- **Tes di Studio (Play):** ketik `!cs 1` di chat, atau di command bar server `workspace:SetAttribute("TestCutscene", "c01_prolog")`.
- **Suara:** id musik/SFX di `audio.ts` masih kosong (cutscene tetap jalan tanpa suara). Tekstur VFX pakai yang udah di-upload 1 Nov.
- **Posisi:** cutscene Prolog dibangun lokal di langit (0, 1200, -4000). Bisa dipindah dengan naruh part bernama `Prolog` di folder `Workspace.CutsceneAnchors`.
