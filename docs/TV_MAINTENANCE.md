# LiveGo TV Maintenance Notes

Dokumen ini adalah patokan maintenance TV agar perubahan tidak salah sasaran.

## Arah Utama TV

TV bukan mobile yang diperbesar. TV harus remote-first, ringan, dan stabil di perangkat RAM kecil.

Target utama:

- Remote responsif.
- Focus selalu terlihat.
- FPS stabil.
- Tidak ada screen berat yang ikut hidup.
- Tidak ada widget jalan kalau tidak sedang dipakai.
- Yang tampil = yang dibutuhkan user saat itu.
- Yang tidak terlihat = jangan rebuild.
- Yang tidak aktif = jangan jalan.
- Yang tidak perlu animasi = hapus.
- Yang bisa static = buat const/static.

## Batas Tanggung Jawab

### TV UI

TV UI hanya bertugas menampilkan layar yang sedang aktif.

Boleh:
- Layout TV.
- Safe margin.
- Zone margin.
- Focus ring.
- Render widget yang sedang terlihat.

Tidak boleh:
- Menjalankan API langsung dari widget render.
- Menyimpan cache besar di screen.
- Menjalankan semua provider bersamaan.
- Memaksa semua screen keep-alive.
- Membuat semua poster aktif/decode bersamaan.

### TV Interaction

Interaction hanya bertugas menangani remote, BACK, cursor, dan perpindahan zone.

Boleh:
- UP/DOWN/LEFT/RIGHT.
- OK/select.
- BACK satu langkah.
- Restore focus ke posisi terakhir.

Tidak boleh:
- Menjalankan API.
- Menyimpan data besar.
- Mengatur render image.
- Membuat FocusNode global di luar owner screen.

### TV Service / Provider

Service/provider hanya bertugas ambil data dan siapkan state ringan.

Boleh:
- Ambil data Home/Search/Detail/Source.
- Normalize data.
- Error state.
- Loading state.

Tidak boleh:
- Mengatur focus.
- Mengatur layout.
- Mengatur scroll TV.
- Membuat UI rebuild berantai tanpa perlu.

## Safe Margin, Zone Margin, Bottom Reach

Patokan layar TV:

- Screen Safe Margin = jarak aman dari tepi layar TV.
- Zone Margin = jarak nyaman untuk focus reveal.
- Bottom Reach = ruang bawah supaya item terakhir bisa naik.

Aturan:
- Long list harus punya bottom reach.
- Grid harus bisa membawa focused item ke area terlihat.
- Overlay player/menu harus pakai safe margin.
- Video surface tidak dipadding; overlay yang dipadding.

## Focus Rules

Gunakan helper sesuai area:

- `tvFocus` untuk tombol/chip/banner kecil.
- `tvFocusComfort` untuk list vertikal ringan.
- `tvFocusGrid` untuk poster grid 2D.
- Direct reveal boleh dipakai hanya jika helper global terbukti telat di device TV.

Jangan pakai:
- FocusTraversalGroup untuk TV remote flow.
- FocusScope.nextFocus.
- directionalFocusInTraversalDirection.
- Banyak autofocus.
- Future.delayed berlapis untuk focus kalau tidak darurat.
- requestFocus raw tanpa alasan jelas.

## BACK Rules

BACK harus satu langkah.

Urutan umum:
- Popup tutup dulu.
- Overlay tutup dulu.
- Subscreen balik ke item terakhir.
- Navbar balik ke screen aktif terakhir.
- Home: Grid → Category → Platform → Banner → Exit Popup.

Jangan:
- BACK menembus beberapa layer.
- BACK dari navbar memaksa Home ke Banner kalau asalnya grid/platform.
- BACK mengubah focus tanpa visual ikut.

## Render Budget

Hindari:
- AnimatedContainer berlebihan.
- Gradient berlapis.
- boxShadow besar.
- Glow.
- Blur.
- Scale poster berlebihan.
- Tooltip di TV.
- Nested RepaintBoundary asal-asalan.

Pakai:
- Container biasa.
- Border jelas.
- Warna solid.
- Focus ring tipis.
- Duration zero.
- Const/static jika mungkin.

## Cache TV

Cache TV bukan tempat API rahasia. Cache TV untuk RAM/FPS.

Cache boleh menyimpan:
- Runtime state kecil.
- Last cursor ringan.
- Episode window ringan.
- Last selected platform/category.
- Render budget flag ringan.

Cache tidak boleh menyimpan:
- BuildContext.
- FocusNode.
- VideoPlayerController.
- Timer aktif.
- Large image bytes.
- Active stream controller.

## Sebelum Patch TV

Checklist:
- Satu patch = satu root problem.
- Scan file target sebelum ubah.
- Jangan sentuh area stabil.
- Jangan tambah listener di root screen kalau tidak perlu.
- Jangan buat semua screen keep-alive.
- Jangan tambah animasi visual.
- Pastikan focus tetap terlihat.
- Pastikan BACK tetap satu langkah.

## TV Black Route Rule

TV route menuju Detail dan Player wajib memakai black zero-transition route.

Aturan:
- Jangan pakai MaterialPageRoute default untuk route TV menuju Player.
- Jangan biarkan default route background putih muncul sebelum destination build.
- Gunakan route hitam opaque dengan transitionDuration zero.
- Detail, Download, History/Favorite/Search/Home harus masuk Player lewat route hitam.
- Video/Player blank putih yang muncul sebelum loading biasanya berasal dari route/parent, bukan VideoPlayer.

## Home Grid Return And Bottom Rule

Home grid finishing rules:
- Opening Player from grid must remember TvZone.grid before pushing Player.
- Returning from Player must restore the exact grid index, not category.
- Home grid uses 7 columns and a 205px poster row height for a smaller finish layout.
- Home grid bottom padding uses `TvSafeZone.homeGridBottomReach` to reduce black empty bottom area.
- DOWN above a partial last row must jump to the last existing poster.

## Home Cache-First Selection Rule

Home platform/category switching must feel instant on TV:
- RAM cache is checked first.
- Disk cache must be checked before network-status checks.
- If disk cache exists, show it immediately and refresh in background.
- Moving focus across Platform/Category chips auto-commits after a short debounce.
- OK still commits immediately.
- Do not wait for the user to press Home/LiveGo again after the chip focus already moved.
- Debounce prevents API spam during fast remote movement.

## Home Cache and Image Responsiveness Rule

Home must not feel like first launch after category/platform was already loaded.
Rules:
- RAM cache must be used even when `clearPrevious=true` for matching platform/category.
- Disk cache is still checked before network.
- TV image decode widths stay small to protect RAM/FPS.
- TV Home grid remains 6 columns; do not switch to 7 just to reduce blank space.
- Heavy high-quality image upgrade must not fight first Home render or remote focus.

## Home Sticky Header Grid Entry Rule

Final Home remote UX:
- Cold start focus stays on Banner.
- DOWN once from Banner enters Grid directly.
- The viewport slides to grid mode so Platform and Category stay visible above posters.
- RIGHT from Banner still enters Platform for manual source/category control.
- UP from first Grid row goes to Category, then Platform, then Banner.
- BACK from Grid returns to the first Home look/Banner.
- BACK from Banner opens the Shell exit popup.
- Do not make Platform/Category disappear during normal grid browsing.

## Source Manager Migration Links Repair

Final rule after Dobda migration:
- Source Manager default route opens platform mode.
- Platform mode shows all supported user platforms and does not show category chips in every row.
- Home Platform header opens Source Manager platform mode.
- Home Kategori header opens Source Manager category mode for the current platform only.
- Category mode can edit Home/LiveGo for that one platform.
- The old 6-platform limit is only a starter default, not a Source Manager lock.
