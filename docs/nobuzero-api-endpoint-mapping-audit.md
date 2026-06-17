# Nobuzero API Endpoint Mapping Audit

Tanggal audit: 2026-06-10
Project: LiveGo Premium TV
Mode: API Endpoint Mapping Audit Only

> Scope: dokumen ini hanya memetakan endpoint Nobuzero API baru ke model, service, provider, dan player existing LiveGo. Tidak ada perubahan kode runtime yang direkomendasikan untuk diterapkan di artifact ini.
>
> Catatan keamanan: secret asli Nobuzero **tidak boleh ditulis** di dokumen, commit, log, atau PR. Gunakan placeholder `<NOBUZERO_SECRET>` / secure config.

## 1. Repo scan yang dilakukan

Instruksi scan user meminta `grep -R`, tetapi environment guideline repo melarang `grep -R` dan mewajibkan `rg`. Audit ini memakai perintah ekuivalen berikut:

```bash
rg -n "class ContentItem|class LiveGoEpisode|class StreamInfo|source|provider|platform|episode|chapter|subtitle|audio|quality|server|search|detail|headers|referrer|userAgent|license|drm" lib android
```

```bash
rg -n "http|Uri\.parse|baseUrl|endpoint|api|nobuzero|aicin|stream|playlist|chapter|Hmac|sha256|X-Signature|X-Timestamp" lib android
```

File penting yang ditemukan:

- `lib/models/content_item.dart`
- `lib/models/livego_episode.dart`
- `lib/models/stream_info.dart`
- `lib/models/livego_detail.dart`
- `lib/models/livego_stream.dart`
- `lib/services/api/api_env.dart`
- `lib/services/api/api_platform.dart`
- `lib/services/api/nobuzero_endpoints.dart`
- `lib/services/api/nobuzero_hmac_signer.dart`
- `lib/services/nobuzero/nobuzero_http_client.dart`
- `lib/services/nobuzero/nobuzero_api_client_impl.dart`
- `lib/services/nobuzero_api_client.dart`
- `lib/services/livego_api_gateway.dart`
- `lib/data/api_manager/api_provider_contract.dart`
- `lib/data/api_manager/api_provider_registry.dart`
- `lib/data/catalog/livego_catalog_home_service.dart`
- `lib/data/catalog/livego_catalog_search_service.dart`
- `lib/data/catalog/livego_catalog_detail_player_service.dart`
- `lib/services/player/playback_resolver.dart`
- `lib/tv/player/tv_player_service.dart`
- `lib/tv/player/explorer3/tv_player_explorer3_native_payload.dart`
- `android/app/src/main/kotlin/com/livego/premium/MainActivity.kt`
- `android/app/src/main/kotlin/com/livego/premium/TvNativeSurfacePlayerActivity.kt`

## 2. Nobuzero API baru: kontrak endpoint

Base URL:

```text
https://api-drama.nobuzero.id
```

Authentication headers untuk request API Nobuzero:

```text
X-Timestamp: {unix milliseconds}
X-Signature: {HMAC-SHA256 hex}
```

Formula signature:

```text
payload = METHOD:FULL_PATH_WITH_QUERY:TIMESTAMP
signature = HMAC-SHA256(<NOBUZERO_SECRET>, payload)
```

Endpoint yang diaudit:

| Endpoint | Fungsi | Params wajib | Mapping fitur LiveGo |
|---|---|---|---|
| `GET /api/v2/home` | Trending / populer | `category_p`, `lang` | Home / populer |
| `GET /api/v2/discover` | Terbaru paginated | `category_p`, `lang`, `page` | Discover / terbaru / pagination |
| `GET /api/v2/categories` | Daftar platform | - | Source manager / platform list |
| `GET /api/v2/banner` | Banner promo | `category_p`, `lang` | Hero/banner home |
| `GET /api/v2/search` | Search drama | `q`, `category_p`, `lang` | Search result |
| `GET /api/v2/video` | Stream URL + subtitle | `id`, `category_p`, `chapterId`, `lang` | Player stream, subtitle, quality, headers player |
| `GET /api/v2/detail` | Detail drama + episode/chapter | `id`, `category_p`, `lang` | Detail screen, episode list, chapter mapping |
| `GET /api/v2/languages` | Daftar bahasa | - | Language source/filter |
| `GET /api/v2/key/status` | Cek status API key | - | API health / key diagnostics |

## 3. Existing model/API/provider LiveGo yang relevan

### 3.1 Model catalog

`ContentItem` adalah model utama card/list UI. Field penting:

- `id`
- `title`
- `source`
- `category`
- `description`
- `posterUrl`
- `backdropUrl`
- `rating`
- `episodes`
- `updated`
- `platformSlug`
- `chapterId`
- `lang`

Factory existing `ContentItem.fromApi` sudah cocok untuk sebagian besar response HOME/DISCOVER Nobuzero:

- `id` dari `json['id']`
- `title` dari `json['title']`
- `source` dari `author` / `platform` / `platformSlug`
- `category` dari `genres[0]` atau `tags[0]`
- `description` dari `synopsis` / `description`
- `posterUrl` dari `cover` / `poster`
- `backdropUrl` dari `backdrop` / `cover` / `poster`
- `episodes` dari `chapters` / `total_episodes` / `totalEpisodes`
- `updated` true jika status mengandung `complete`
- `chapterId` default `1`

Gap model: `views` belum punya field eksplisit; saat ini `_parseRating` hanya mengubah format string views `M/K` menjadi rating statis. Jika `views` angka seperti sample `128235`, popularity tidak tersimpan sebagai angka.

### 3.2 Model episode/chapter

`LiveGoEpisode` berisi:

- `id`
- `index`
- `title`

Factory existing mengambil `id` dari `id` / `chapterId` / `index`, `index` dari `index` / `id`, dan title fallback `Episode {index/id}`. Ini cocok untuk `/api/v2/detail` jika `chapters[]` berisi id chapter asli. Nobuzero `/video` wajib memakai `chapterId`; karena itu mapping episode index ke chapter id harus dijaga dari detail response.

### 3.3 Model stream/player

`StreamInfo` berisi:

- `url`
- `episodeIndex`
- `totalEpisodes`
- `nextEpisodeId`
- `prevEpisodeId`
- `headers`
- `subtitles`
- `qualities`

Factory existing `StreamInfo.fromApi` dan parser Nobuzero existing sudah mendukung:

- `data.streams[]` menjadi `StreamQuality`
- URL stream dari `url` / `src` / `videoUrl` / `hlsUrl` / `streamUrl`
- label quality dari `label` / `quality` / `resolution`
- `data.streamHeaders` menjadi `headers`
- default stream header `User-Agent: okhttp/4.12.0` dan `Accept: */*`
- `data.subtitles[]` menjadi `SubtitleTrack`
- `episode_index`, `total_episodes`, `next_video_id`, `prev_video_id`

`LiveGoStream` juga ada, tetapi path player TV yang dominan memakai `StreamInfo`.

### 3.4 Provider/gateway/catalog boundary

Flow API existing:

```text
UI / TV providers
  -> LiveGoCatalog
  -> catalog services
  -> LiveGoApiManager + ApiProviderRegistry
  -> LiveGoApiGateway
  -> NobuzeroApiClient
  -> NobuzeroApiClientImpl
  -> NobuzeroHttpClient
```

`LiveGoApiProviderContract` sudah mendefinisikan kemampuan provider: home, discover, collection, search, detail, episodes, video, fastVideo, subtitle, audio.

`LiveGoApiProviderRegistry` memakai `_GatewayApiProvider` dan capability Nobuzero saat ini:

- `subtitle` mengikuti `config.supportsSubtitle`
- `audio` hardcoded `false`
- video aktif selama bukan encrypted

Ini sesuai sample Nobuzero: subtitle tersedia, audio track list tidak tersedia di API.

## 4. Pemetaan endpoint ke fitur LiveGo

| Fitur | Endpoint Nobuzero | Existing entry point | Catatan mapping |
|---|---|---|---|
| Home | `GET /api/v2/home?category_p={platform}&lang={lang}` | `LiveGoCatalog.home` -> `LiveGoCatalogHomeService.home` -> gateway -> Nobuzero client | Untuk trending/populer. Existing Nobuzero client sudah punya `_homeRaw`. |
| Discover / Terbaru | `GET /api/v2/discover?category_p={platform}&lang={lang}&sort=desc&page={page}` | `LiveGoCatalog.discover` / `homeNextPage` / catalog home service | Existing `_discoverRaw` memakai `category_p`, `lang`, `page`, `limit=20`; belum memakai `sort=desc`. |
| Platform/category source | `GET /api/v2/categories` | `LiveGoCatalogPlatformService`, `LiveGoApiPlatforms` | Existing source list masih hardcoded starter pack; endpoint categories cocok untuk dynamic source manager nanti. |
| Banner | `GET /api/v2/banner?category_p={platform}&lang={lang}` | `LiveGoCatalog.banners` / `hero` / `LiveGoCatalogHomeService.banners` | Existing Nobuzero client punya `banner`. Perlu cek UI expectation apakah data shape sama dengan ContentItem. |
| Search | `GET /api/v2/search?q={query}&category_p={platform}&lang={lang}&page={page}` | `LiveGoCatalog.search` -> `LiveGoCatalogSearchService.search` | Existing client mencoba param `q`, lalu fallback `query`. API baru mewajibkan `q`; `query` fallback bisa tetap legacy saja. |
| Detail | `GET /api/v2/detail?id={id}&category_p={platform}&lang={lang}` | `LiveGoCatalog.detail` / `episodes` -> detail player service | Detail harus menyimpan chapter id asli dari `chapters[]` untuk `/video`. |
| Episode/chapter | Dari `/api/v2/detail` `chapters[]` | `LiveGoEpisode` list + `_episodeMemory` | Mapping penting: UI boleh minta episode index, provider harus resolve ke chapter id asli. Existing code sudah punya `_chapterIdForEpisode`. |
| Stream/play | `GET /api/v2/video?id={id}&category_p={platform}&chapterId={chapterId}&lang={lang}` | `PlaybackResolver.resolveStreamInfo` / `TvPlayerService.resolveStream` | Response `data.streams[]` ke `StreamInfo.url` dan `qualities`. |
| Subtitle | Dari `/api/v2/video` `data.subtitles[]` | `StreamInfo.subtitles` -> native payload -> Android player | External SRT URL. Existing Android native player dapat build `MediaItem.SubtitleConfiguration`. |
| Quality | Dari `/api/v2/video` `data.streams[]` | `StreamInfo.qualities` -> `qualityLabels`/`qualityUrls` | Sudah ada multiple quality payload. Risiko sample hanya `auto`. |
| Audio | Tidak ada field audio di sample/API list | Native media tracks only | Jangan invent audio endpoint. Audio tetap dari ExoPlayer/native track discovery. |
| Headers player | Dari `/api/v2/video` `data.streamHeaders` | `StreamInfo.headers` -> native payload -> Android data source headers | Jangan dicampur dengan HMAC API headers. |
| Language | `GET /api/v2/languages` + `lang` param endpoint lain | `LiveGoApiPlatforms.supportedLangs` / platform service | Existing language list hardcoded per platform. Endpoint languages bisa dipakai untuk dynamic config nanti. |
| Key health | `GET /api/v2/key/status` | API health/status diagnostics | Cocok untuk `ping`/diagnostics, bukan content UI langsung. |

## 5. Pemetaan field response

### 5.1 HOME/DISCOVER/BANNER/SEARCH item

| Nobuzero field | Existing mapping | Status |
|---|---|---|
| `id` | `ContentItem.id` | Jelas |
| `title` | `ContentItem.title` | Jelas |
| `author` | `ContentItem.source` | Jelas |
| `platform` | `ContentItem.source` fallback | Jelas |
| `cover` | `ContentItem.posterUrl`, `ContentItem.backdropUrl` fallback | Jelas |
| `synopsis` | `ContentItem.description` | Jelas |
| `status` | `ContentItem.updated` boolean complete-derived | Sebagian; string status tidak disimpan eksplisit |
| `genres[]` | `ContentItem.category` first non-empty genre | Sebagian; list penuh tidak tersimpan |
| `tags[]` | `ContentItem.category` fallback first tag | Sebagian; list penuh tidak tersimpan |
| `chapters` | `ContentItem.episodes` | Jelas, perlu parse int/string |
| `views` | Tidak ada field eksplisit; rating heuristic | Gap; popularity/views hilang |
| `platform` top-level response | Source/platform context | Perlu dipakai untuk diagnostics/log, bukan item wajib |
| `total` top-level response | Pagination/count metadata | Gap jika UI butuh total pages/count |

### 5.2 DETAIL response

| Nobuzero field | Existing mapping | Status |
|---|---|---|
| `data.id` | `ContentItem.id` / `LiveGoDetail.id` | Jelas |
| `data.title` | `ContentItem.title` / `LiveGoDetail.title` | Jelas |
| `data.cover` | poster/backdrop/detail cover | Jelas |
| `data.synopsis` | description/synopsis | Jelas |
| `data.author` | source/author | Jelas |
| `data.status` | status / `updated` heuristic | Sebagian |
| `data.genres[]` / `tags[]` | category first value | Sebagian |
| `data.chapters[]` | `List<LiveGoEpisode>` | Kritis untuk chapter id asli |
| `chapters[].id` / `chapterId` | `LiveGoEpisode.id` | Jelas jika field tersedia |
| `chapters[].index` / episode number | `LiveGoEpisode.index` | Jelas |
| `chapters[].title` | `LiveGoEpisode.title` | Jelas |

### 5.3 VIDEO response

| Nobuzero field | Existing mapping | Status |
|---|---|---|
| `data.streams[]` | `StreamInfo.qualities` | Jelas |
| `data.streams[0].url` | `StreamInfo.url` default | Jelas |
| `data.streams[].url` | `StreamQuality.url`, native `qualityUrls` | Jelas |
| `data.streams[].quality` | `StreamQuality.label`, native `qualityLabels` | Jelas |
| `data.streams[].resolution` | label fallback | Jelas |
| `data.streams[].duration` | Tidak disimpan di `StreamInfo` | Gap; sample `0`, risiko rendah untuk playback |
| `data.subtitles[]` | `StreamInfo.subtitles` | Jelas |
| `data.subtitles[].url` | `SubtitleTrack.url`, native `subtitleUrls` | Jelas |
| `data.subtitles[].format` | `SubtitleTrack.format`, native `subtitleFormats` | Jelas |
| `data.subtitles[].language` | `SubtitleTrack.language`, native `subtitleLabels` | Jelas |
| `data.streamHeaders` | `StreamInfo.headers`, native `headers` | Jelas |
| `data.episode_index` | `StreamInfo.episodeIndex` | Jelas |
| `data.total_episodes` | `StreamInfo.totalEpisodes` | Jelas |
| `data.next_video_id` | `StreamInfo.nextEpisodeId` | Perlu verifikasi apakah id chapter atau episode number |
| `data.prev_video_id` | `StreamInfo.prevEpisodeId` | Perlu verifikasi apakah id chapter atau episode number |
| `data.duration` | Tidak disimpan di `StreamInfo` | Gap; sample `0`, tandai risiko |
| `data.is_free` | Tidak dipakai | Gap; jika perlu badge/free gating nanti |
| `data.title` | Tidak dipakai di `StreamInfo`; item title tetap dipakai | Non-blocking |

## 6. Authentication/header analysis

### 6.1 API auth header

Nobuzero API request butuh:

```text
X-Timestamp: {unix milliseconds}
X-Signature: HMAC-SHA256(<NOBUZERO_SECRET>, METHOD:FULL_PATH_WITH_QUERY:TIMESTAMP)
```

Existing repo sudah memiliki helper signing di `lib/services/api/nobuzero_hmac_signer.dart` dan low-level client di `lib/services/nobuzero/nobuzero_http_client.dart`.

Mapping helper yang cocok:

- Signing tetap di `lib/services/api/nobuzero_hmac_signer.dart`.
- Transport tetap di `lib/services/nobuzero/nobuzero_http_client.dart`.
- Provider/parser tetap di `lib/services/nobuzero/nobuzero_api_client_impl.dart`.
- Jangan letakkan signing di UI, catalog service, provider registry, atau native player.

Risiko signature:

- Timestamp harus akurat, toleransi biasanya ±5 menit.
- Signature harus memakai `FULL_PATH_WITH_QUERY`, bukan full URL host.
- Query order bisa mempengaruhi signature. Karena `Uri.replace(queryParameters: map)` membentuk query dari insertion order Map Dart, patch berikutnya perlu memastikan order query yang dipakai untuk URL sama persis dengan order saat signing.
- Jangan encode ulang query berbeda antara build URL dan signature payload.

### 6.2 Stream/player headers

`streamHeaders` dari response `/video` adalah header untuk player/video CDN, bukan auth header Nobuzero API. Mapping yang benar:

```text
Nobuzero API auth headers -> hanya NobuzeroHttpClient request
streamHeaders -> StreamInfo.headers -> native player data source
```

Jangan mencampur:

- `X-Timestamp` / `X-Signature` **tidak** boleh otomatis dikirim ke stream URL.
- `streamHeaders.User-Agent` boleh dikirim ke player URL.

### 6.3 Secret/config

Existing `ApiEnv` menyimpan `baseUrl`, `apiKey`, `nobuzeroBaseUrl`, dan `nobuzeroSecret` sebagai constant. Untuk implementasi produksi berikutnya:

- Jangan hardcode secret baru di kode.
- Gunakan placeholder saat dokumentasi: `<NOBUZERO_SECRET>`.
- Ideal patch: pindahkan Nobuzero secret ke build-time config / dart-define / secure CI secret, lalu fallback aman untuk local dev.
- Audit ini tidak menulis secret asli Nobuzero ke artifact.

## 7. Subtitle analysis

API menyediakan subtitle sebagai external SRT URL:

```json
{
  "language": "id",
  "format": "srt",
  "url": "https://api-dracin.nobuzero.id/api/proxy/subtitle?url=...srt"
}
```

Existing support:

- `StreamInfo` punya `List<SubtitleTrack>`.
- Native payload mengirim `subtitleLabels`, `subtitleUrls`, dan `subtitleFormats`.
- `MainActivity` meneruskan list subtitle ke `TvNativeSurfacePlayerActivity` via intent extras.
- Native player membangun `MediaItem.SubtitleConfiguration`; format `srt` dipetakan ke `MimeTypes.APPLICATION_SUBRIP`, `vtt/webvtt` ke `MimeTypes.TEXT_VTT`.

File yang perlu disentuh jika patch subtitle nanti:

- `lib/services/nobuzero/nobuzero_api_client_impl.dart` untuk parsing subtitle Nobuzero.
- `lib/models/stream_info.dart` jika ingin memperluas metadata subtitle.
- `lib/tv/player/explorer3/tv_player_explorer3_native_payload.dart` jika payload perlu field baru.
- `android/app/src/main/kotlin/com/livego/premium/TvNativeSurfacePlayerActivity.kt` jika SRT proxy butuh header khusus, conversion, atau selected subtitle behavior.

Risiko subtitle:

- Subtitle SRT external mungkin tidak kompatibel di semua device jika server memberi MIME salah.
- Proxy subtitle host `api-dracin.nobuzero.id` berbeda dari base API `api-drama.nobuzero.id`.
- Jika subtitle URL expired, player perlu resolve stream ulang.
- Jika CDN butuh header khusus untuk subtitle URL, schema saat ini belum punya per-subtitle headers.

## 8. Quality analysis

API quality berasal dari `data.streams[]`:

```json
{
  "quality": "auto",
  "resolution": "auto",
  "url": "https://...m3u8"
}
```

Existing support:

- `StreamInfo.qualities` bisa membawa multiple quality URL.
- Native payload sudah mengirim `qualityLabels` dan `qualityUrls`.
- Android native player menyimpan `QualityRow`, menambahkan row `Auto`, lalu membuat ulang ExoPlayer dengan URL quality yang dipilih.

Patch yang mungkin dibutuhkan nanti:

- Pastikan label tidak duplikat jika `quality=auto` dan `resolution=auto` untuk banyak stream.
- Pertimbangkan label gabungan seperti `quality/resolution` jika Nobuzero mengirim `quality=auto`, `resolution=720p`.
- Jika only one stream `auto`, UI quality tetap menampilkan Auto saja.
- Jika HLS master playlist sudah punya variant quality, ExoPlayer bisa auto-adapt tanpa multiple URL; jangan paksa split quality jika API hanya memberi auto.

Risiko quality:

- Sample menunjukkan `auto` saja.
- `duration` pada stream sample `0`, jangan dipakai untuk progress/duration final.
- Stream URL bisa expired; cache TTL stream harus pendek.

## 9. Audio analysis

API sample dan endpoint list tidak menyediakan audio track list. Tidak ada field seperti:

- `audios`
- `audioTracks`
- `dubTracks`
- `languages` per stream audio

Kesimpulan:

- Audio harus tetap berasal dari native media player/media track discovery.
- Jangan membuat/mengarang endpoint audio baru.
- Capability provider `audio` tetap `false` untuk API-level audio.
- UI audio track tetap boleh aktif dari ExoPlayer native tracks.

Existing Android native player sudah membaca current tracks ExoPlayer dan membangun daftar audio dari track language/label/channel count. Jadi Nobuzero API tidak perlu mapping audio list.

## 10. Platform/category source analysis

Known platform IDs dari request user:

```text
melolo, dramabox, pinedrama, freereels, meloshort, reelshort, reelife, dramawave, stardusttv, netshort, goodshort, shortmax, flickreels, flextv, dramarush, rapidtv, dramatv, dramanova, fundrama, starshort, dramapops, snackshort, dramabite, sodareels, bilitv, idrama, cubetv, shortwave, reelala, shotshort, microdrama, radreels, sereal
```

Jumlah known IDs di atas: 33.

Sample `/api/v2/categories` menunjukkan sebagian platform:

```json
[
  {"id": 1, "name": "melolo", "display_name": "Melolo"},
  {"id": 2, "name": "dramabox", "display_name": "DramaBox"},
  {"id": 4, "name": "freereels", "display_name": "FreeReels"}
]
```

Existing `LiveGoApiPlatforms` hanya mengekspos starter pack:

- `nobuzero_freereels` -> `freereels`
- `nobuzero_goodshort` -> `goodshort`
- `nobuzero_dramawave` -> `dramawave`
- `nobuzero_reelshort` -> `reelshort`
- `nobuzero_reelife` -> `reelife`
- `nobuzero_rapidtv` -> `rapidtv`

Mismatch/risiko:

- Known platform list 33 item, existing starter pack hanya 6.
- User notes platform list bisa 32/33 data; endpoint `/categories` harus dianggap authoritative saat runtime.
- Beberapa platform mungkin tidak aktif dalam plan `starter` walaupun ada di known list.
- Source manager sebaiknya menampilkan platform yang diizinkan oleh `/categories` dan/atau feature flag, bukan semua known list mentah.

## 11. File mapping detail untuk implementasi berikutnya

### 11.1 File yang kemungkinan perlu diubah

1. `lib/services/api/api_env.dart`
   - Pindahkan secret ke secure config / dart-define.
   - Jangan hardcode `<NOBUZERO_SECRET>` di source.

2. `lib/services/api/nobuzero_hmac_signer.dart`
   - Pastikan payload memakai exact `uri.path?uri.query`.
   - Tambahkan test helper deterministic timestamp jika testing diperlukan.

3. `lib/services/nobuzero/nobuzero_http_client.dart`
   - Pastikan query order stabil dan sama dengan signed URI.
   - Tambahkan support `GET /api/v2/key/status`, `/languages`, `/categories` bila belum tersedia di facade.

4. `lib/services/api/nobuzero_endpoints.dart`
   - Endpoint utama sudah ada, termasuk `keyStatus`; tinggal pastikan tidak menambah endpoint fiktif.

5. `lib/services/nobuzero/nobuzero_api_client_impl.dart`
   - Tambahkan `sort=desc` untuk discover jika harus mengikuti contoh baru.
   - Pastikan search utama memakai `q`.
   - Pastikan detail chapters disimpan dan dipakai untuk mapping `episode index -> chapterId`.
   - Tambahkan API categories/languages/key status facade bila akan dipakai UI.

6. `lib/services/nobuzero_api_client.dart`
   - Expose categories/languages/key status jika dibutuhkan.

7. `lib/services/livego_api_gateway.dart`
   - Expose categories/languages/key status jika catalog/source manager akan consume dynamic data.

8. `lib/services/api/api_platform.dart`
   - Tambah mapping platform Nobuzero yang belum ada jika source manager belum dibuat dynamic.
   - Alternatif lebih aman: tetap starter pack, lalu dynamic categories sebagai opt-in.

9. `lib/data/catalog/livego_catalog_platform_service.dart`
   - Integrasi `/categories` dan `/languages` untuk source manager/filter.

10. `lib/models/content_item.dart`
    - Opsional: tambah `views`/`popularity` jika UI/ranking butuh.
    - Opsional: simpan `status` string dan tags list jika UI detail butuh.

11. `lib/models/stream_info.dart`
    - Opsional: simpan duration/isFree jika nanti diperlukan.
    - Existing support quality/subtitle/headers sudah cukup untuk minimal patch.

12. `lib/tv/player/explorer3/tv_player_explorer3_native_payload.dart`
    - Hanya perlu diubah jika payload subtitle/quality/header ditambah; existing sudah cukup.

13. `android/app/src/main/kotlin/com/livego/premium/TvNativeSurfacePlayerActivity.kt`
    - Hanya perlu diubah jika SRT external gagal, perlu subtitle headers, atau behavior quality/audio perlu disempurnakan.

### 11.2 File yang sebaiknya jangan disentuh untuk patch minimal

- UI layout yang tidak terkait source/player:
  - `lib/mobile/**` kecuali mobile memang masuk scope.
  - `lib/tv/account/**`, `lib/tv/settings/**`, `lib/tv/update/**`.
- Native Android player jika parsing Dart sudah cukup dan subtitle SRT berjalan.
- Model legacy `LiveGoStream` kecuali masih dipakai jalur tertentu; prioritas tetap `StreamInfo`.
- Mock catalog kecuali test/demo membutuhkan sample Nobuzero.

## 12. Rekomendasi implementasi patch berikutnya

### 12.1 Patch minimal aman

1. Secure config:
   - Ganti hardcoded Nobuzero secret menjadi `String.fromEnvironment('NOBUZERO_SECRET')` atau mekanisme secure config project.
   - Pastikan report/log tidak mencetak secret.

2. Stabilkan HTTP signing:
   - Build URI sekali, sign URI yang sama.
   - Query Map insertion order harus deterministic per endpoint.
   - Tambah unit test signer dengan timestamp fixed dan query fixed.

3. Discover/search alignment:
   - Tambah `sort=desc` untuk `/discover` jika API baru mengharuskan hasil terbaru desc.
   - Jadikan `q` sebagai primary search param; fallback `query` boleh tetap untuk compatibility.

4. Dynamic platform/language read-only:
   - Tambah method `categories()`, `languages()`, `keyStatus()` di Nobuzero client/gateway.
   - Jangan langsung expose semua 33 platform ke Home default; gunakan source manager opt-in atau starter pack.

5. Field gap opsional:
   - Tambah `views`/`statusText`/`tags` di model hanya jika UI membutuhkan.
   - Jangan ubah model luas jika patch endpoint cukup.

### 12.2 Urutan implementasi yang disarankan

1. Tambah/rapikan secret injection dan signer tests.
2. Tambah endpoint facade untuk categories/languages/key status.
3. Update discover/search params sesuai kontrak baru.
4. Verifikasi detail chapters dan video chapterId mapping dengan sample nyata.
5. Verifikasi player native:
   - streamHeaders masuk ExoPlayer request.
   - subtitle SRT external muncul.
   - quality list tidak duplikat.
6. Baru integrasikan dynamic platform list ke source manager.
7. Baru pertimbangkan model extensions `views`, `statusText`, `tags`, `duration`, `isFree`.

## 13. Test checklist untuk patch berikutnya

### Unit/logic

- Signer menghasilkan `X-Timestamp` dan `X-Signature` dengan payload `GET:/api/v2/home?category_p=freereels&lang=id:{timestamp}`.
- Signer memakai full path with query, bukan base URL.
- Query order sama antara URI request dan payload signature.
- `ContentItem.fromApi` parse HOME/DISCOVER sample:
  - id/title/source/poster/description/episodes/category/lang/platformSlug benar.
- Detail parser parse `chapters[]` ke `LiveGoEpisode` dengan id chapter asli.
- Video parser parse:
  - `streams[]` -> `StreamInfo.qualities`
  - first stream -> `StreamInfo.url`
  - `subtitles[]` -> `SubtitleTrack`
  - `streamHeaders` -> `headers`
  - episode/total/next/prev.

### Integration/API

- `GET /api/v2/key/status` dengan HMAC berhasil.
- `GET /api/v2/categories` mengembalikan plan dan platform list.
- `GET /api/v2/languages` mengembalikan bahasa.
- `GET /api/v2/home?category_p=freereels&lang=id` tampil Home.
- `GET /api/v2/discover?...&sort=desc&page=1` tampil Terbaru.
- `GET /api/v2/search?q=ceo&...` tampil hasil search.
- `GET /api/v2/detail?id=...` mengembalikan chapters.
- `GET /api/v2/video?id=...&chapterId=...` mengembalikan m3u8 dan subtitle.

### Player/native

- Stream HLS bisa play dengan `streamHeaders.User-Agent`.
- API auth headers tidak ikut terkirim ke stream URL.
- Subtitle SRT external tampil di Android TV.
- Quality menu menampilkan Auto + labels dari `streams[]` tanpa duplikat merusak UX.
- Audio menu tetap berasal dari ExoPlayer tracks, bukan API.
- Next/prev episode tidak loncat karena chapterId mapping benar.
- Stream cache TTL pendek cukup untuk URL yang mungkin expired.

## 14. Risiko utama

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Timestamp harus akurat ±5 menit | 401/403 auth API | Gunakan device/server time yang benar; log skew tanpa secret |
| Signature harus `FULL_PATH_WITH_QUERY` | Auth gagal | Test signer deterministic |
| Query order mempengaruhi signature | Auth gagal intermittent | Build URI once dan sign URI final |
| Duration sample `0` | Progress/duration tidak akurat | Jangan andalkan API duration; biarkan player membaca media duration |
| Audio tidak tersedia dari API | Tidak bisa pre-populate audio list | Tetap pakai native media track discovery |
| Subtitle SRT external | Subtitle bisa gagal di device tertentu | Pastikan MIME SRT dan fallback VTT/conversion jika perlu |
| Streams bisa hanya `auto` | Quality menu minim | UI tetap aman dengan Auto saja |
| Stream URL mungkin expired | Playback gagal setelah cache lama | Stream cache TTL pendek dan resolve ulang saat error |
| Cover/subtitle proxy beda host | CORS/header/cache beda | Jangan asumsikan host sama dengan API base |
| Platform list 32/33 mismatch | Source manager menampilkan platform invalid | Treat `/categories` as authoritative per plan/key |
| Secret hardcoded | Security leak | Pindah ke secure config/dart-define |
| `next_video_id`/`prev_video_id` ambiguity | Episode next/prev loncat | Verifikasi apakah id chapter atau index; prefer detail chapters mapping |

## 15. Kesimpulan audit

Mapping endpoint Nobuzero API baru ke arsitektur LiveGo sudah cukup jelas untuk patch minimal:

- HOME/DISCOVER/BANNER/SEARCH dapat dipetakan ke `ContentItem`.
- DETAIL dapat dipetakan ke `ContentItem` + `LiveGoEpisode` dan menjadi sumber chapter id asli.
- VIDEO dapat dipetakan ke `StreamInfo`, `StreamQuality`, `SubtitleTrack`, dan native player payload.
- Subtitle external SRT sudah punya jalur model -> payload -> Android native player.
- Quality multiple URL sudah punya jalur model -> payload -> Android native player.
- Audio tidak disediakan API; audio tetap native player/media track.
- HMAC API auth dan `streamHeaders` player harus tetap dipisah.

Field yang belum jelas / gap:

- `views` belum tersimpan eksplisit.
- `status` string belum tersimpan eksplisit di `ContentItem`.
- `genres/tags` list penuh belum tersimpan.
- `duration` dan `is_free` video belum tersimpan di `StreamInfo`.
- `next_video_id` / `prev_video_id` perlu diverifikasi apakah chapter id atau episode number.
- Dynamic `/categories` dan `/languages` belum menjadi source of truth UI; existing masih starter pack hardcoded.

Rekomendasi patch berikutnya: mulai dari secure secret + signer determinism, lalu align params `discover/search`, lalu expose read-only categories/languages/key status, lalu verifikasi detail-video chapter mapping dan subtitle/quality player behavior sebelum memperluas model/UI.
