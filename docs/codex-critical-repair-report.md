# Codex Critical Repair Report — Android TV Public Release

## 1. Tanggal dan tujuan audit

- Tanggal audit: 2026-06-10.
- Tujuan audit: melakukan **Full Critical Repair Sweep** untuk public release Android TV LiveGo Premium TV.
- Fokus audit: native player progress/preference sync, update flow, TV Settings parity, Source Manager remote safety, cache maintenance, Account TV, dan Home regression risk.

## 2. Semua masalah yang ditemukan

1. Native player Activity belum mengirim `position`/`duration` saat pause, exit, destroy, atau sebelum mengganti quality/subtitle/episode.
2. Flutter hanya menyimpan progress dari fallback `VideoPlayerController`; saat native surface player dipakai, Continue Watching dapat tidak update.
3. Event native belum memiliki identity kuat (`playbackKey`, episode, chapter), sehingga stale native callback berisiko menulis progress/preference ke video atau episode lain.
4. Native player belum menyinkronkan pilihan user untuk quality, subtitle, audio, dan speed kembali ke Flutter settings/preferences.
5. Payload native belum membawa preferensi awal quality/subtitle/audio/speed dari Flutter, sehingga native player selalu mulai dari default internal jika user sudah memilih preferensi lain.
6. Update flow membuka installer langsung setelah APK selesai di-download. Ini bukan silent install, tetapi untuk public release TV lebih aman jika install hanya terjadi setelah user memilih tombol Install Update.
7. TV Settings belum menampilkan parity setting penting yang sudah ada di logic core/mobile: `backgroundPoster`, `cachePlayback`, `manualRotateButton`, `drmMode`, status/locked `tvHomeGrid`, Source Manager, dan cache maintenance detail.
8. Scan repeat/focus menemukan `FocusTraversalGroup` di rail Home. Remote-first rule meminta tidak memakai `FocusTraversalGroup`.
9. Account TV masih memiliki item Bantuan dan Feedback yang hanya menampilkan pesan placeholder.
10. Cache Maintenance sudah mencakup beberapa cache penting, tetapi audit memastikan hasil partial success/failure harus tetap terlihat dan tidak reset settings.
11. Source Manager sudah memiliki OK guard 320ms, ignore `KeyRepeatEvent` untuk OK/BACK/MENU, BACK ladder, dan popup Simpan/Batal yang aman; tidak ditemukan blocker di area ini.
12. Home controller sudah memiliki guard untuk mencegah reload pada LEFT/RIGHT Platform/Category dan OK item sama; tidak ditemukan regression nyata yang membutuhkan perubahan controller.

## 3. Kategori masalah

### CRITICAL / wajib sebelum publik

1. Native player progress sync tidak lengkap untuk pause/exit/dispose dan pergantian episode/quality/subtitle.
2. Native event tidak punya stale-event guard yang cukup kuat.
3. Native player preference sync tidak lengkap untuk quality/subtitle/audio/speed.
4. Update flow membuka installer otomatis setelah download selesai, bukan menunggu aksi Install eksplisit.
5. TV Settings parity belum menampilkan setting public-release penting.
6. `FocusTraversalGroup` masih ada di Home rail, bertentangan dengan remote-first rule.

### HIGH / sebaiknya sebelum publik

1. Account TV item Bantuan dan Feedback masih placeholder. Ditunda karena tidak ada existing screen/action aman yang setara; membuat dummy palsu berisiko menyesatkan user.
2. Native audio track selection masih memakai preferred audio language dari Media3. Ini aman dan tidak crash, tetapi stream yang tidak punya language/label unik bisa membuat pilihan audio tidak sepresisi track-index native penuh.

### MEDIUM / boleh setelah publik

1. Update manifest hanya memakai satu URL GitHub Release tanpa mirror/fallback.
2. UI Cache Maintenance menampilkan label cache yang gagal, tetapi belum menampilkan stack/error detail lengkap per item.
3. Manual QA Home perlu dijalankan di device Android TV fisik untuk memastikan tidak ada variasi remote vendor.

### LOW / cleanup nanti

1. Beberapa label player masih campuran Indonesia-Inggris.
2. Dokumentasi remote QA dapat diperluas dengan matriks perangkat dan firmware.

## 4. Root cause tiap masalah

1. Native player berjalan di Android Activity terpisah, sementara MethodChannel sebelumnya hanya menangani `resolveEpisode`, `nativeClosed`, dan `setAutoNext`.
2. Flutter progress saver `_saveProgressNow` bergantung pada fallback `VideoPlayerController`, sehingga tidak membaca posisi native Activity.
3. Payload native sebelumnya hanya berisi metadata playback dasar tanpa stable playback identity untuk validasi callback balik.
4. Perubahan quality/subtitle/audio/speed di native hanya mengubah state native Activity dan toast, belum memanggil Flutter untuk persist.
5. Update screen memanggil `_openInstaller()` langsung setelah `downloadApk()` sukses.
6. TV Settings enum sudah punya beberapa setting, tetapi daftar section UI hanya memuat layout TV, download notice, dan reset cache.
7. Home rail masih memakai traversal wrapper lama walaupun handler remote manual sudah tersedia.

## 5. File yang terkait

- `android/app/src/main/kotlin/com/livego/premium/MainActivity.kt`
- `android/app/src/main/kotlin/com/livego/premium/TvNativeSurfacePlayerActivity.kt`
- `lib/tv/player/explorer3/tv_player_explorer3_native_payload.dart`
- `lib/tv/player/explorer3/tv_player_explorer3_screen.dart`
- `lib/tv/update/tv_update_screen.dart`
- `lib/tv/update/tv_update_service.dart`
- `lib/tv/settings/tv_settings_screen.dart`
- `lib/tv/settings/tv_settings_models.dart`
- `lib/tv/cache/tv_cache_maintenance_service.dart`
- `lib/tv/source_manager/tv_source_manager_screen.dart`
- `lib/tv/account/tv_account_screen.dart`
- `lib/tv/widgets/tv_home_rail_section.dart`
- `lib/tv/home/tv_home_interaction_controller.dart`

## 6. Rencana perbaikan

1. Tambahkan `chapterId`, `playbackKey`, dan preferensi awal ke payload native.
2. Tambahkan native progress event dengan `positionMs`/`durationMs` pada pause/destroy dan sebelum switching playback.
3. Tambahkan handler Flutter untuk menerima native progress dengan stale guard dan validasi agar progress 0 tidak menimpa progress valid.
4. Tambahkan native preference event untuk quality/subtitle/audio/speed, lalu persist ke `PlayerPreferences`, `LiveGoSettings`, dan local settings jika didukung.
5. Ubah update flow agar download selesai menampilkan state ready; installer hanya dibuka saat user memilih Install Update.
6. Tambahkan kembali TV Settings penting dan hubungkan Source Manager dari Settings.
7. Hapus `FocusTraversalGroup` dari rail Home tanpa mengubah controller Home/navbar.
8. Dokumentasikan sisa HIGH/MEDIUM yang tidak aman diselesaikan di PR ini.

## 7. Perubahan yang benar-benar dilakukan di PR ini

1. `MainActivity.kt` meneruskan `chapterId`, `playbackKey`, `selectedQuality`, `selectedSubtitle`, `selectedAudio`, dan `selectedSpeed` ke native player Activity.
2. `TvNativeSurfacePlayerActivity.kt` sekarang:
   - membaca preferensi awal quality/subtitle/audio/speed secara defensif;
   - mengirim `nativeProgress` pada pause, destroy, sebelum episode switch, sebelum quality switch, dan sebelum subtitle switch;
   - tidak mengirim progress jika duration/position tidak valid atau position 0;
   - mengirim `nativePreference` saat user mengubah speed, quality, subtitle, dan audio;
   - mengabaikan repeat BACK/MENU native;
   - tetap tidak crash jika list quality/subtitle/audio tidak tersedia.
3. `tv_player_explorer3_native_payload.dart` menambahkan stable `playbackKey` dan preferensi awal ke payload native.
4. `tv_player_explorer3_screen.dart` sekarang:
   - memuat `PlayerPreferences` sebelum membuka native player;
   - menerima `nativeProgress` dan menyimpan progress hanya jika identity cocok;
   - menolak stale event dan progress 0/invalid;
   - menerima `nativePreference` dan menyimpan quality/subtitle/audio/speed jika event berasal dari playback aktif.
5. `tv_update_screen.dart` tidak lagi membuka installer otomatis setelah download; user harus memilih tombol Install Update secara eksplisit.
6. `tv_settings_screen.dart` menampilkan kembali `backgroundPoster`, `cachePlayback`, `manualRotateButton`, `drmMode`, `tvHomeGrid` locked status, `downloadWifiOnly`, Source Manager, dan Cache Maintenance.
7. `tv_home_rail_section.dart` menghapus `FocusTraversalGroup` dan tetap memakai handler FocusNode/manual remote yang sudah ada.
8. Artifact audit ini ditambahkan di `docs/codex-critical-repair-report.md`.

## 8. Perubahan yang sengaja tidak dilakukan dan alasannya

1. Tidak mengubah provider/API routing karena tidak ditemukan compile blocker yang membutuhkan perubahan routing.
2. Tidak mengubah `pubspec.yaml` sesuai batasan user.
3. Tidak menghapus legacy/fallback player karena masih dipakai sebagai fallback saat native open gagal.
4. Tidak mengubah desain besar-besaran; perubahan UI hanya menambahkan setting penting yang hilang.
5. Tidak mengganti domain update/manifest; domain GitHub Release existing tetap dipakai.
6. Tidak mengubah Home controller/navbar karena audit tidak menemukan regression nyata pada controller; perubahan Home hanya menghapus wrapper traversal yang dilarang.
7. Tidak membuat screen palsu untuk Account Bantuan/Feedback. Item tersebut dicatat sebagai HIGH karena belum ada target screen/action existing yang aman.
8. Tidak menambahkan audio track selection berbasis track index native penuh karena perlu validasi Media3 lebih dalam; implementasi sekarang tetap aman dan tidak crash.

## 9. Risiko

1. Native MethodChannel progress/preference event bersifat asynchronous; stale guard sudah ditambahkan, tetapi tetap perlu QA saat user sangat cepat pindah episode lalu keluar.
2. Persist preference native bergantung pada label quality/subtitle/audio; jika source memberi label duplikat, pilihan tersimpan tetapi bisa ambigu pada stream berikutnya.
3. Gradle compile lokal tidak bisa diselesaikan di environment ini karena Gradle 7.6.3 gagal dengan Java class file major version 69. CI dengan JDK yang sesuai harus memverifikasi build.
4. Karena `dart`/`flutter` CLI tidak tersedia di environment ini, format/analyze Flutter tidak bisa dijalankan lokal.
5. Update download tetap bergantung pada GitHub Release manifest dan koneksi network device.

## 10. Checklist test manual Android TV

- Build CI harus hijau dengan JDK/Flutter yang sesuai project.
- Home tidak regress:
  - Platform/Category LEFT/RIGHT tidak reload.
  - OK item sama tidak reload.
  - OK item beda reload 1x.
  - BACK ladder Grid -> Category -> Platform -> Banner -> Exit.
  - Navbar origin restore tetap aman.
- Source Manager:
  - OK cepat toggle hanya 1x.
  - `KeyRepeatEvent` OK/BACK/MENU diabaikan.
  - BACK tetap satu langkah.
  - Popup Simpan/Batal aman.
- Cache Maintenance:
  - Clear image cache.
  - Clear RAM cache.
  - Clear runtime cache.
  - Clear player cache.
  - Clear content cache.
  - Clear LiveGo image cache manager.
  - Clear DefaultCacheManager.
  - Hasil berhasil/gagal sebagian tampil jelas.
  - Settings tidak reset saat hapus cache.
- TV Settings:
  - `backgroundPoster` tampil dan toggle.
  - `cachePlayback` tampil dan toggle.
  - `manualRotateButton` tampil dan toggle.
  - `drmMode` tampil dan bisa cycle LEFT/RIGHT/OK.
  - `tvHomeGrid` tampil sebagai locked status.
  - `downloadWifiOnly` tampil dan toggle.
  - Source Manager bisa dibuka.
  - Cache Maintenance bisa dijalankan.
- Native player:
  - Progress tersimpan saat pause.
  - Progress tersimpan saat exit/BACK sampai Activity destroy.
  - Progress tersimpan sebelum ganti episode/quality/subtitle.
  - Continue Watching akurat untuk episode/chapter yang diputar.
  - Stale native event tidak overwrite episode/video lain.
  - Progress valid tidak ditimpa dengan 0.
  - Quality/subtitle/audio/speed tersimpan jika native support/list tersedia.
  - Tidak crash jika quality/subtitle/audio list kosong.
- Update:
  - State sudah terbaru tampil jelas.
  - State update tersedia tampil jelas.
  - Manifest invalid/gagal network tampil sebagai gagal cek update, tidak crash.
  - Download APK stabil dan progress tampil.
  - OK cepat saat download tidak membuat download dobel.
  - Installer tidak terbuka otomatis setelah download; hanya terbuka setelah pilih Install Update.
- Remote global:
  - Fokus selalu terlihat.
  - OK satu aksi.
  - BACK satu langkah.
  - Arrow boleh repeat tanpa focus lompat liar.
