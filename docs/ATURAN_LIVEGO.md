# Aturan LiveGO Premium

Dokumen ini adalah **satu tempat** aturan main LiveGO: alur TV, alur mobile,
aturan provider, dan aturan-aturan yang ditambahkan selama pengembangan.
Baca ini sebelum tambah provider, ubah TV, ubah player, atau bersih-bersih.

Dokumen detail yang sudah ada (jangan diduplikasi di sini, cukup di-link):

- `docs/TV_MAINTENANCE.md` — maintenance TV (remote, focus, layout).
- `docs/API_MAINTENANCE.md` — maintenance API (provider-agnostic, tanpa UI).
- `docs/PLAYBACK_CONTRACT.md` — batas aman API/provider vs Player.
- `docs/PLAYER_MAINTENANCE.md` — maintenance player.
- `docs/UPDATE_MAINTENANCE.md` — maintenance updater.
- `lib/tv/home/ARCHITECTURE.md` + `BOUNDARY.md` — architecture lock Home TV.

## Lapisan arsitektur

```
UI (mobile screens / tv screens)
  -> DramaSourceRegistry (lib/services/drama_source.dart)
    -> Provider adapter (FreereelsSource / CinemaIdSource / MeloloSource / ShortTvSource)
      -> Client (HTTP + auth + decrypt) -> Proxy lokal (stream)
  -> LiveGoCatalog (platform non-drama / facade)
  -> LiveGoLocalStore + LiveGoSettings (persistensi)
  -> LiveGoContentCache (disk cache konten, mobile)
```

- UI tidak tahu protokol provider. Semua lewat registry.
- Provider tidak tahu UI/focus/remote. Provider hanya ambil + normalkan data.
- Player tidak tahu API. Player terima stream URL + extras dari resolver.

## Alur TV — 3 area, masing-masing punya manager

TV bukan mobile yang diperbesar. Prinsip: **setipis mungkin, render hanya
yang tampil di layar, remote-first.**

### Home TV (`lib/tv/home/`)

- Layout di `tv_home_screen.dart`, interaksi di
  `tv_home_interaction_controller.dart`, data di
  `tv_home_provider.dart` (controller) + `tv_home_repository.dart`.
- Render: `TvPosterGrid` (Sliver builder + `ValueKey` stabil per item).
  Hanya sel terlihat yang dibangun. **Tidak ada cap jumlah item.**
- Data: pagination bertahap — halaman 1 = 2 baris (2 × jumlah kolom
  grid = 14 konten saat kolom 7). Layar pertama penuh 2 baris, baris
  ke-3 tidak lagi terlihat separuh.
- Header Home (border provider + kategori) TIDAK pinned — ikut
  kedorong ke atas saat scroll, viewport jadi konten penuh (3 baris).
  Balik ke chip (UP dari grid) jump ke anchor 228, header tetap
  kelihatan di sana. Scroll TIDAK nambah data; data nambah hanya
  lewat `loadMore()`.
  Scroll masuk zona lookahead (~2 baris sebelum ujung) -> `loadMore()`.
  Append dedupe by id (`mergePagedItems`). Fokus tidak terganggu karena
  item lama tidak berubah posisi dan key stabil.
- Cache: disk cache = halaman 1 saja (placeholder + offline), RAM cache =
  state tergabung. Refresh halaman 1 = stale-while-revalidate.
- Kategori terakhir per provider tersimpan (`tvLastHomeCategories`) dan
  dipulihkan saat masuk provider. Hanya kategori aktif yang di-load —
  tab lain hibernasi total (nol request).
- Manager yang dipakai Home:
  - `TvRemoteManager` — filter tombol, repeat rate limiting, debounce.
    Cooldown klik 280ms, navigasi 110ms.
  - `TvBackManager` — BACK ladder + debounce 280ms (lihat bawah).
  - `TvCacheManager` — cache TV tetap tipis, prune background, tanpa
    blokir frame.

### Akun TV (`lib/tv/account/`)

- Menu data-driven (`TvAccountMenuData`) + aksi di `TvAccountScreen`.
- Menu akun adalah tempat aksi sesi per provider (Keluar CinemaID /
  ShortTV). Sign-out membuang sesi; request berikutnya memakai identitas
  baru otomatis.
- BACK / remote memakai manager yang sama dengan Home.

### Player TV (`lib/tv/player/`)

- Player punya cache manager sendiri (aktif):
  - `TvPlayerCacheManager` — cache pintar player: daftar episode
    (maks 24 list, maks 80 episode/list, maks 12 in-flight) + stream
    (maks 64 entri, maks 64 gagal). Semua ber-cap, tidak menumpuk.
- Player TIDAK punya focus controller khusus yang aktif. File lama
  `TvPlayerFocusController` (focus guard player) sudah tidak dipakai
  siapa pun — masuk daftar hapus (lihat "Aturan kebersihan"). Player
  yang jalan sekarang memakai layar player bersama + `TvRemoteManager`
  / `TvBackManager`. Kalau focus guard khusus player dibutuhkan lagi,
  tulis baru mengikuti pola manager TV, jangan menghidupkan file mati.
- BACK di player: tutup overlay/dialog dulu, baru keluar (via
  `TvBackManager`).
- Prefetch episode berikutnya setelah player terbuka (kualitas provider
  yang sama). Prefetch tidak boleh menumpuk tanpa batas.

### BACK ladder TV (berlaku semua area)

1. Tutup dialog/modal yang terbuka.
2. Tab non-Home -> kembali ke Home di posisi terakhir.
3. Home -> dialog konfirmasi keluar aplikasi.
4. Semua BACK lewat `TvBackManager.canHandleBack()` + debounce.

## Alur Mobile — Home, Akun, Player

- Home (`mobile_home_screen.dart`): state eksplisit + infinite scroll.
  Halaman 1 = 2 baris (grid 3 kolom -> 6 item, layar pertama penuh
  2 baris). Layout ramping: hero 170, border provider/kategori
  (chip 28, padding 8/6), navbar bawah 62. Scroll masuk zona
  lookahead (~300px) -> halaman berikut. Footer spinner / tombol
  retry kalau gagal. Pull-to-refresh = halaman 1 fresh.
- Kategori terakhir per provider tersimpan di map yang sama dengan TV
  (`tvLastHomeCategories`, persist di settings) dan dipulihkan saat masuk
  provider. Hanya kategori aktif yang di-load.
- Cache: stale-while-revalidate (cache tampil instan, halaman 1 fresh
  dari server menggantikannya). Cache = placeholder + fallback offline,
  bukan sumber kebenaran.
- Akun + Pengaturan (`mobile_account_screen.dart`,
  `mobile_settings_screen.dart`): seksi "Sesi Provider" untuk Keluar
  CinemaID / ShortTV. FreeReels (anonim) dan Melolo (identitas perangkat)
  tidak punya sesi akun.
- Player mobile: satu resolver (`PlaybackResolver`) untuk mobile + TV.
  Kualitas/subtitle per provider tersimpan terpisah
  (`player.preferences.byProvider`); provider tanpa override memakai
  nilai global.

## Aturan provider (checklist tambah provider baru)

- **FreeReels**: kategori = tab APK: Popular (503), Coming Soon (622),
  Sulih Suara (514), Anime (547). New (505), Female (504), Male (506)
  DIHAPUS. Label Indonesia ("Sulih Suara", bukan "Dubbing").
  Sulih Suara = konten trending/Indonesia — tarik SEMUA konten sulih
  suara: tab 514 + halaman search "sulih suara" (token cache), di jalur
  `homePage` (paged) maupun `homeByCategory` (legacy).

Tiru pola provider yang sudah ada. Urutan kerja:

1. **Adapter**: class `XSource implements DramaSource`, daftarkan SATU baris
   di `DramaSourceRegistry`. Tanpa ubah Home/Player/repository.
2. **Kontrak wajib**: `slug`, `label`, `categories`, `homeByCategory`,
   `episodes`, `streamUrl`. Opsional dengan default aman: `search`,
   `episodeExtras`, `signOut`, `homePage`.
3. **Pagination (WAJIB)**: implementasi `homePage(category, {page,
   pageSize})` — SATU halaman per request, ikut page server.
   - `page` 1-based. `pageSize` hanya permintaan; server boleh
     mengembalikan jumlah berapapun — jangan mengasumsikan pageSize.
   - `hasMore=false` kalau server bilang habis (halaman kosong / tidak
     ada item baru). Deteksi habis: halaman kosong, atau semua item
     duplikat halaman sebelumnya (seen-set, reset tiap page 1).
   - **DILARANG** fetch semua halaman di depan (`allSeriesFromTab`,
     `allVodsFromTopic`, dsb). Itu yang bikin load berat.
   - **DILARANG** cap katalog (tidak ada `take(28)` / batas jumlah).
     Katalog 1000 item harus aman karena datang bertahap.
4. **Auth dinamis-first (WAJIB)**: sesi dibangun dinamis
   (tersimpan -> login/handshake/register -> fallback hardcoded).
   - Hardcoded (token/device) hanya cadangan TERAKHIR, bukan jalur utama.
   - Token ditolak (401/403/kode auth) -> pulih otomatis sekali (sesi
     baru + retry). Gagal kedua -> error jelas, jangan gagal diam.
   - `login`/`register` WAJIB persist sesi (jangan hilang saat restart).
   - `signOut()` WAJIB: buang sesi tersimpan + runtime. Request
     berikutnya memakai identitas baru otomatis.
   - Provider tanpa sesi akun (anonim / identitas perangkat): `signOut`
     no-op + jelaskan di komentar kenapa.
5. **Error auth bertipe (WAJIB)**: penolakan server (risk control,
   USER_NOT_LOGIN, dst) dilempar sebagai exception bertipe
   (`XxxAuthException`) berpesan jelas — bukan exception generik, bukan
   daftar kosong diam-diam.
6. **Hibernasi**: provider/kategori tidak aktif tidak fetch apa pun.
   Tidak ada prefetch tab tetangga. Tidak ada request di background
   untuk tab yang tidak dilihat.
7. **Kategori terakhir**: kategori yang dipilih user tersimpan per
   provider (`tvLastHomeCategories`) dan dipulihkan saat masuk provider.
8. **Kualitas**: ganti kualitas WAJIB re-resolve URL (bukan tempel query
   ke URL lama). `streamUrl` menerima kualitas; Melolo/ShortTV memilih
   definisi video sesuai kualitas.
9. **Test (WAJIB)**: tiap aturan baru ditemani test unit untuk bagian
   murninya (deteksi auth, dedupe merge, hasMore). Jalankan test terkait
   + `flutter analyze` file terkait = 0 error sebelum push.
10. **Versi (WAJIB)**: tiap perubahan bump `pubspec.yaml`
    (format `x.y.z+N`) supaya in-app updater mendeteksi.

## Aturan yang sudah ditambahkan (riwayat)

- **Stale-while-revalidate**: cache tampil instan, server tetap ditanya,
  UI diganti saat fresh datang. (Mobile + TV.)
- **Auth dinamis-first + sign-out**: CinemaID auto-register identitas
  tamu baru + recovery sekali; ShortTV handshake 12 jam + retry;
  Melolo identitas perangkat TETAP (kredensial kerja jangan dihapus),
  penolakan dilempar `MeloloAuthException`.
- **Pagination + infinite scroll**: `homePage`, `mergePagedItems`,
  viewport + lookahead (mobile 2 baris, TV 2 baris), trigger di zona
  lookahead, footer retry.
- **Pilih provider/kategori TV = OK-only.** Hover/lewat chip (fokus
  pindah) HANYA menggerakkan kursor — `selected` tidak ikut, tidak ada
  request. Konten baru ter-load saat user tekan OK
  (`_selectPlatform` / `_selectCategory`). Chip yang dilewati remote
  tidak boleh memicu trigger.
- **Hibernasi tab + restore kategori terakhir per provider.**
- **Preferensi per provider**: kualitas + subtitle tersimpan per
  provider, tidak saling mengubah.
- **Ganti kualitas = re-resolve URL**, bukan tempel query.
- **Prefetch episode berikutnya** setelah player terbuka (terbatas,
  tidak menumpuk).
- **Melolo progressive streaming**: Range/decrypt per segmen, fallback
  ke download-full kalau CDN/moov tidak mendukung.

## Aturan kebersihan (sampah)

- **Audit dulu, hapus setelah disetujui.** File/kode yang tidak dipakai
  jangan dihapus buta — cek import/part/export, lalu hapus setelah
  disetujui. Git bisa mengembalikan, tapi jangan andalkan itu.
- **Jangan tambah file tanpa pemakai.** File baru harus di-import
  sesuatu / didaftarkan (registry, route, docs).
- **Jangan commit sampah**: file draft (`.patch`), artifact build
  (`.dart_tool/`, `build/`, `GeneratedPluginRegistrant.java`) tidak
  masuk commit. Commit hanya file sumber + test yang dimaksud.
- **`flutter analyze` file terkait = 0 error** sebelum push. Warning
  unused (`unused_import`, `unused_field`, `unused_element`) dibersihkan
  kalau menyentuh file itu; jangan refactor massal file lain.
- **Satu dokumen aturan ini** adalah acuan. Kalau aturan berubah, ubah
  dokumen ini dulu, baru kode — supaya provider berikutnya meniru
  aturan yang benar, bukan aturan lama.
