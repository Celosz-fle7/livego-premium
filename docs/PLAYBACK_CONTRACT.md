# LiveGo Playback Contract

Dokumen ini menjelaskan batas aman antara API/provider dan Player.

## Tujuan

Kalau API pindah atau bentuk response berubah, Player jangan dibongkar.

Yang boleh berubah:
- API client.
- Provider adapter.
- Mapper/normalizer.
- LiveGoCatalog / PlaybackResolver.
- Provider registry/config.

Yang tidak boleh ikut berubah hanya karena API pindah:
- tv_player_screen.dart.
- player remote mapping.
- BACK flow.
- control dock.
- episode panel.
- focus controller.
- overlay widget.

## Alur Wajib

API baru / API lama:

```text
Provider API
  ↓
API Client
  ↓
Adapter / Mapper / Normalizer
  ↓
LiveGoCatalog / PlaybackResolver
  ↓
TvPlayerService
  ↓
TvPlayerScreen
```

Player hanya boleh menerima data normal:

```text
StreamInfo
- url
- headers
- qualities
- subtitles
- episodeIndex
- totalEpisodes
- nextEpisodeId
- prevEpisodeId
```

## Yang Tidak Boleh Masuk Player

Player tidak boleh tahu:

- baseUrl.
- API key.
- endpoint path.
- raw JSON.
- provider API response field.
- encrypted/decrypt detail.
- chapter id rule per provider.
- fallback endpoint order.

Kalau ada API baru, mapping di service layer dulu sampai menjadi StreamInfo.

## StreamInfo Contract

Minimal agar player bisa jalan:

```text
url: non-empty video url
headers: User-Agent dan Accept aman
qualities: optional; kalau kosong pakai url sebagai Auto
subtitles: optional
episodeIndex: current episode
totalEpisodes: total episode
```

Jika API punya field berbeda:

```text
videoUrl / src / file       → StreamInfo.url
streamHeaders / headers    → StreamInfo.headers
resolution / quality/label → StreamQuality.label
subtitle url/lang          → SubtitleTrack
next/prev id               → nextEpisodeId / prevEpisodeId
```

## Provider Config

Provider config boleh menyimpan:

- slug.
- label.
- baseUrl.
- apiKey jika diperlukan.
- endpoint contract.
- supportsSubtitle.
- supportsQuality.
- supportsAudio.
- isEncrypted.
- videoType.

Provider config tidak boleh masuk Player UI.

## Maintenance Rule

Saat pindah API:

1. Tambah/update adapter.
2. Mapping raw JSON ke model standar.
3. Pastikan `PlaybackResolver.fastStreamInfo` dan `resolveStreamInfo` tetap return `StreamInfo`.
4. Test Player tanpa mengubah UI.
5. Baru ubah Player jika ada fitur baru yang benar-benar butuh UI baru.

## Anti-Pattern

Jangan lakukan:

- `tv_player_screen.dart` import API client.
- Player baca API key.
- Player parse JSON response.
- Player tahu endpoint video/detail.
- Player tahu format khusus provider.
- Player punya if providerSlug terlalu banyak.

Kalau butuh provider-specific logic, letakkan di adapter/resolver.
