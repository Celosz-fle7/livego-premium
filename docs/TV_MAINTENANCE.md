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
