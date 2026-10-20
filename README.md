# Qi Cultivation (roblox-ts + Rojo)

Project script game Qi Cultivation. Kode baru ditulis pakai TypeScript (roblox-ts) di `src/`, terus Rojo nyambungin hasilnya ke Studio. Script Luau lama yang udah jalan disimpan apa adanya di `luau/` dan ikut disambungin juga, nanti dipindah ke TypeScript satu per satu.

## Isi folder

| Folder | Isi | Masuk ke Studio sebagai |
|---|---|---|
| `src/shared` | Modul TypeScript yang dipakai server dan client | `ReplicatedStorage.TS` |
| `src/server` | Script server TypeScript (`*.server.ts`) | `ServerScriptService.TS` |
| `src/client` | Script client TypeScript (`*.client.ts`) | `StarterPlayer.StarterPlayerScripts.TS` |
| `luau/shared` | Modul Luau lama | `ReplicatedStorage.Luau` |
| `luau/server` | Script server Luau lama | `ServerScriptService.Luau` |
| `luau/client` | LocalScript Luau lama | `StarterPlayerScripts.Luau` |

Rojo cuma ngatur folder `TS` dan `Luau` di atas. Isi lain di Studio (map, CombatCore, QiClient, dan lainnya) nggak disentuh.

## Yang udah masuk

- `src/shared/weaponScale.ts` dan `src/server/weaponScale.server.ts`: skala senjata ngikutin tinggi avatar. Ini script pertama yang udah ditulis ulang ke TypeScript.
- `luau/server/WeaponSkills.server.lua`: skill Z/X/G dan pasif 4 pedang.
- `luau/client/WeaponSkillClient.client.lua`: input, cut-in, dan efek skill pedang.
- `luau/client/SkillScrollHUD.client.lua`: gulungan skill di pojok kanan bawah (PC).
- `luau/client/WeaponVFXClient.client.lua`: petir di Spirit Sword.
- `luau/shared/WeaponCombo.lua`: combo 4 hit jadi satu modul. Sekarang tiap pedang punya salinan LocalScript sendiri (5 salinan). Nanti diganti LocalScript kecil di tiap Tool:
  ```lua
  require(game.ReplicatedStorage:WaitForChild("Luau"):WaitForChild("WeaponCombo"))(script.Parent)
  ```
  Satu baris di modul ini masih sementara (cek "lagi meditasi atau nggak"). Baris aslinya ada di `StarterPack.QiSword.ComboClient` dan baru bisa disalin dari Studio.

## Yang belum masuk

Script ini cuma ada di Studio, jadi harus ditarik dulu: QiClient, CombatCore, ComboClient dan HitServer (QiSword), SprintServer dan SprintClient, ZoneLighting, SerpentAnimator, AttachScabbard, WeaponRackGive, ComboServer di tiap pedang, dan script lain yang ada di place.

Caranya: simpan place ke file lokal di laptop (File > Save to File As, bukan publish), terus jalanin `rojo syncback` biar semua script keluar jadi file. Habis itu tiap script dicocokin dan dipindah ke folder di atas.

## Cara nyambungin ke Studio (di laptop)

Butuh Node.js (LTS) dan Rojo 7.7.1 (udah ada di `C:\Users\Shen\Project\ROBLOX\Rojo`).

1. Buka terminal di folder project ini, jalanin `npm install` sekali.
2. Jalanin `npm run watch`. Biarin kebuka, tiap file `src/` disimpan langsung di-compile ke `out/`.
3. Di terminal lain jalanin `rojo serve`.
4. Di Studio buka plugin Rojo, klik Connect.

**Penting sebelum Connect pertama kali:** script yang sekarang ada di Studio dengan nama yang sama (misalnya `ServerScriptService.WeaponSkills`, `StarterPlayerScripts.WeaponSkillClient`, `SkillScrollHUD`, `WeaponVFXClient`) harus dihapus dulu. Kalau nggak, script-nya jalan dua kali. Ini nunggu oke Will karena berarti hapus script di place.

## Perintah

| Perintah | Fungsi |
|---|---|
| `npm run build` | Compile TypeScript sekali |
| `npm run watch` | Compile otomatis tiap file disimpan |
| `rojo serve` | Nyambungin project ke Studio |
| `rojo build -o test.rbxlx` | Bikin place percobaan dari project (buat ngecek struktur) |
