# LiveGo API Maintenance Notes

Dokumen ini adalah patokan maintenance API agar perubahan API tidak mengganggu TV UI, Player, cache, atau focus remote.

## Arah Utama API

API bertugas mengambil dan menormalkan data. API tidak boleh mengatur UI, focus, remote, layout, atau widget.

Target:
- Provider-agnostic.
- Mudah diganti sumber.
- Tidak membebani Home/Player.
- Tidak membuat UI freeze.
- Tidak refresh semua provider bersamaan.
- Tidak menjalankan request dari widget render langsung.

## Batas Tanggung Jawab

### API Client

Tugas:
- Request network.
- Header/API key.
- Parse response mentah.
- Timeout.
- Error mapping dasar.

Jangan:
- Mengatur UI.
- Mengatur focus.
- Mengatur cache UI.
- Mengatur Player overlay.
- Mengatur TV layout.

### Repository / Catalog

Tugas:
- Menyatukan provider.
- Normalize Home/Search/Detail/Episode/Stream.
- Fallback antar endpoint.
- Return model bersih.

Jangan:
- Menyimpan BuildContext.
- Mengetahui FocusNode.
- Memaksa rebuild UI.
- Membawa logic visual.

### Cache API

Tugas:
- Mengurangi request network.
- TTL per endpoint.
- Provider-agnostic key.
- Data ringan dan bisa expire.

Jangan:
- Dipakai sebagai TV render cache.
- Menyimpan state focus.
- Menyimpan VideoPlayerController.
- Menyimpan UI cursor.
- Menyimpan widget.

## Cache API vs Runtime Cache TV

API cache:
- Untuk data server.
- TTL.
- Provider/platform/endpoint/params.
- Contoh: Home, Search, Detail, Episode list.

TV runtime cache:
- Untuk RAM/FPS/remote.
- Tidak punya TTL network.
- Kecil.
- Tidak listener.
- Contoh: last cursor, render window, last selected zone.

Jangan dicampur.

## TTL Rekomendasi

- Home/Trending/ForYou: 4 jam.
- Latest: 1 jam.
- Search: 15-30 menit.
- Detail: 24 jam.
- Episode list: 24 jam.
- Video stream: jangan cache sebagai data permanen kecuali ada desain khusus.

## Provider Rules

Provider aktif default:
- ShortMax.
- NetShort.
- PineDrama.
- DramaBox.
- FlickReels.

Catatan:
- Melolo jangan default jika masih kompleks DRM/decrypt/audio.
- Jangan aktifkan provider baru sebelum Player/Home stabil.
- Dobda lama jangan aktif di main route jika sudah diganti Anichin.

## Player API Rules

Player boleh minta:
- Stream info.
- Detail fallback.
- Episode list.
- Subtitle file.

Player tidak boleh:
- Memaksa API refresh semua provider.
- Load semua episode besar tanpa batas.
- Menjalankan API dari widget overlay.
- Mengubah UI focus karena API selesai.

Jika API lambat:
- UI tetap hitam/loading aman.
- Remote tetap bisa BACK keluar.
- Tidak boleh freeze.

## Error Handling

API error harus return state yang bisa dipakai UI:

- Loading.
- Empty.
- Error message pendek.
- Retry possible.
- Partial data jika ada.

Jangan lempar error mentah sampai UI crash.

## Sebelum Patch API

Checklist:
- Apakah patch ini memengaruhi Home?
- Apakah patch ini memengaruhi Player?
- Apakah patch ini memengaruhi cache?
- Apakah patch ini mengubah model?
- Apakah ada timeout?
- Apakah fallback jelas?
- Apakah UI tetap bisa BACK saat API lambat?
- Apakah provider lain tidak ikut rusak?

Satu patch API harus satu root problem.

## Dobda Home / LiveGo / Platform Rules

Current TV API rule:
- Home uses `/api/v2/home` as the fast path.
- Home must not wait for `/api/v2/discover` before showing content.
- `/api/v2/discover` is fallback/background material only.
- LiveGo remains an app-level category built from `/api/v2/search` because Dobda has no real `/livego` endpoint.
- Platform list must show all user-selected Home platforms.
- The current 6 Dobda platforms are starter defaults only, not a permanent user lock.
- Default platform list means initial/reset choice. User choice from Source Manager must remain respected.
