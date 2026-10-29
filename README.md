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
