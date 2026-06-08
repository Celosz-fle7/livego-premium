# LiveGo TV Player Maintenance Notes

Dokumen ini adalah patokan maintenance Player agar Player tetap ringan, remote stabil, dan tidak salah sasaran.

## Arah Utama Player

Player harus terasa seperti TV player, bukan mobile player.

Target:
- Video surface full black/fullscreen.
- Overlay memakai safe margin + zone margin.
- Remote satu pintu.
- Root focus satu.
- Tidak ada overlay yang rebut focus.
- Tidak ada widget player yang jalan kalau tidak tampil.
- Tidak decode gambar saat player startup kalau tidak perlu.
- Tidak membebankan satu bagian.

## Pembagian Tanggung Jawab

### tv_player_screen.dart

Tugas:
- Host utama Player.
- Memiliki VideoPlayerController.
- Menghubungkan state, service, render, dan interaction.
- Menjaga lifecycle controller.
- Memanggil widget overlay yang sedang tampil.

Jangan:
- Menjadi tempat semua render widget.
- Menjadi tempat cache besar.
- Menjadi tempat API fallback baru tanpa service.
- Menambah FocusNode per tombol tanpa kebutuhan kuat.

### tv_player_focus_controller.dart

Tugas:
- Root focus Player.
- BACK cooldown.
- OK/select cooldown.
- Klasifikasi tombol remote.

Jangan:
- Menyimpan overlay state.
- Menjalankan API.
- Menjalankan seek.
- Memiliki FocusNode tombol satu-satu.

### tv_player_service.dart

Tugas:
- Resolve stream.
- Fallback stream.
- Detail/episode API jika dibutuhkan Player.

Jangan:
- Mengatur UI.
- Mengatur focus.
- Mengatur overlay.
- Mengatur BuildContext.

### widgets/

Tugas:
- Render yang tampil saja.
- Control dock.
- Episode panel.
- Choice panel.
- Loading/status/subtitle overlay.
- Error overlay.

Jangan:
- Menjalankan API.
- Menyimpan timer.
- Mengubah controller langsung kecuali diberi callback eksplisit.
- Membuat listener baru tanpa alasan jelas.

## Remote Mapping Target

Watching mode:
- OK = play/pause.
- LEFT = seek -10 detik.
- RIGHT = seek +10 detik.
- UP = show controls.
- DOWN = episode list.
- BACK = exit player.

Controls visible:
- LEFT/RIGHT = pindah tombol control.
- OK = aktifkan tombol.
- DOWN = episode list.
- BACK = hide controls.
- UP = masuk speed/options atau hide sesuai flow final.

Episode list:
- UP/DOWN = pindah episode.
- OK = pilih episode.
- BACK/LEFT = tutup panel atau kembali ke controls.

Popup/options:
- UP/DOWN = pindah item.
- LEFT/RIGHT = ubah nilai jika sesuai.
- OK = pilih/terapkan jika sesuai.
- BACK = kembali satu langkah.

## BACK Rules Player

BACK wajib satu langkah:

- Quality/subtitle/options popup → controls.
- Episode panel → controls atau clean screen sesuai asal.
- Controls → clean video.
- Clean video → exit ke asal poster/detail.
- Loading/error tanpa controller → exit player.

Jangan:
- BACK langsung keluar saat overlay masih terlihat.
- BACK menembus dua layer.
- BACK membuat Shell/Home ikut mengambil focus sebelum player selesai pop.

## Safe Margin dan Zone Margin Player

Video surface:
- Fullscreen black.
- Jangan diberi padding safe margin.

Overlay:
- Control dock bawah wajib SafeArea bottom.
- Subtitle wajib bottom safe margin.
- Status toast wajib bottom safe margin.
- Episode panel kanan wajib SafeArea top/bottom.
- Quality/subtitle/options popup wajib safe bottom/side.
- Error/loading overlay wajib SafeArea.

## Render Budget Player

Hindari:
- AnimatedContainer di item yang sering berubah.
- Shadow/glow di tombol overlay.
- Gradient berlapis.
- Backdrop image saat player startup.
- Render semua episode list penuh.
- Render semua overlay bersamaan.
- Listener progress banyak.

Pakai:
- Solid black startup.
- Container biasa.
- Border focus jelas.
- Episode visible window.
- Overlay hanya jika tampil.
- Root focus tunggal.

## Player Cache / Runtime Cache

Player perlu cache untuk RAM/FPS, bukan keamanan API.

Boleh cache:
- Last episode cursor.
- Last selected episode.
- Last watch position.
- Last quality/subtitle/audio/speed preference.
- Episode visible window ringan.
- Last known episode count ringan.

Jangan cache:
- VideoPlayerController.
- BuildContext.
- FocusNode.
- Timer.
- Stream aktif/controller.
- Subtitle besar tanpa batas.
- Image bytes.

## Jangan Diubah Tanpa Alasan Kuat

Area rawan:
- VideoPlayerController lifecycle.
- Stream resolve order.
- Episode next/prev by ordered list.
- Broken episode skip.
- Progress save.
- Subtitle parse/fetch.

Jika tidak ada bug nyata, jangan refactor area ini.

## Final Stability Lock

Fondasi Player dianggap stabil jika semua aturan ini tetap dijaga:

- Root focus tetap satu di Player.
- Tidak memakai FocusTraversalGroup.
- Tidak memakai FocusScope.nextFocus atau previousFocus.
- Tidak memakai directional focus traversal.
- Cursor overlay tetap manual state, bukan FocusNode per tombol.
- Overlay cursor boleh punya guard ringan, tapi guard harus di-reset saat mode overlay berubah.
- Seek LEFT/RIGHT tidak boleh ikut throttle overlay cursor.
- Loading tanpa controller tidak boleh membuka popup/episode/options.
- BACK tetap satu langkah: popup → controls → video bersih → exit.
- Video surface tetap fullscreen black; safe margin hanya untuk overlay.
- Request stream tetap lewat TvPlayerService, bukan UI.
- API detail/all-episode warm-up tidak boleh masuk active startup path lagi.
- Runtime cache hanya untuk state kecil, bukan stream/video/controller.

## Blank White Guard

Player tidak boleh pernah menampilkan surface putih saat startup.

Aturan:
- Root Player wajib dibungkus black Material/Scaffold.
- Stack dasar wajib ColoredBox hitam.
- VideoPlayer hanya dirender jika controller initialized dan size video valid.
- Jika size video masih 0x0, tetap tampil black startup guard.
- Jika native video texture belum siap, tampil loading overlay ringan di atas black surface.
- Jangan render backdrop/image saat player startup.
- Jangan padding video surface; safe margin hanya overlay.

## Native Texture Shield

Jika blank putih masih muncul walaupun VideoPlayerController sudah initialized, penyebabnya biasanya native texture Android TV belum menggambar frame pertama.

Aturan tambahan:
- Setelah controller ready, VideoPlayer boleh dirender di belakang shield hitam.
- Shield hitam tetap di atas texture sampai posisi video mulai bergerak.
- Shield wajib dilepas saat first moving frame terdeteksi.
- Shield punya batas aman pendek agar tidak jadi overlay permanen.
- Shield timer wajib di-cancel saat dispose.
- Shield tidak boleh memengaruhi remote, BACK, API, atau request stream.

## Startup Overlay Priority

Player startup overlay harus punya prioritas jelas:

- Loading overlay hanya tampil jika tidak ada blocking error.
- Error overlay harus bisa menang walaupun `_loading` masih true saat race singkat.
- Pesan auto-skip episode seperti "gagal, lanjut Episode" tetap boleh tampil sebagai loading/progress.
- Native texture shield fallback timer tidak boleh berhenti hanya karena `isBuffering` true pada satu tick.
- Jika shield fallback timer berhenti tanpa retry, UI bisa terlihat stuck.

## Episode Bounds Rule

TV Player boleh mendukung long-running series tanpa merender semua episode.

Aturan:
- Jangan batasi episode TV ke 120 jika API menyediakan lebih.
- Batas safety saat ini 999 episode untuk remote dan cache ringan.
- Episode panel tetap render visible window kecil, bukan semua episode.
- Window episode tetap 11 row agar RAM/FPS aman.
- Jika batas episode diubah, ubah Player dan Episode Panel bersama-sama.

## Explorer3 Episode Route Rule

Explorer3 episode switching must update both episode number and provider chapter id.

Rules:
- Do not switch episodes by setting `_episode` only.
- `_changeEpisode()` and `_selectEpisodeCursor()` must resolve target through `_resolveOrderedEpisodeTarget()`.
- Always update `_episode`, `_chapterId`, and `_episodeCursor` together before `_load()`.
- This fixes the case where the episode list appears but every selection keeps playing the first/original chapter.
- Do not patch old `tv_player_screen.dart` for Explorer3 runtime bugs unless it is proven active again.
