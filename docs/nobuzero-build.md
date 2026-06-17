# Panduan Build Nobuzero (LiveGo Premium)

Dokumentasi ini menjelaskan cara melakukan build APK/AAB untuk sistem Nobuzero v2 yang menggunakan sistem Auth HMAC dinamis.

## Persyaratan Build
Aplikasi membutuhkan credential yang dikirim via `--dart-define` saat proses compile. Jika tidak disertakan, aplikasi akan menampilkan pesan error konfigurasi dan tidak akan melakukan request ke server untuk menghemat kuota data/resource.

### Variabel Environment
| Nama | Deskripsi | Default |
|------|-----------|---------|
| `LIVEGO_BASE_URL` | URL Base API v2 | `https://nobuzero.my.id/api/v2` |
| `LIVEGO_NOBUZERO_BASE_URL` | URL Base API Nobuzero | `https://nobuzero.my.id/api/v2` |
| `LIVEGO_USER_ID` | User ID dari Admin UI | (Kosong) |
| `LIVEGO_SECRET` | Secret Key dari Admin UI | (Kosong) |

## Command Build

### 1. Build APK Release
Gunakan command ini untuk menghasilkan file installer APK:

```bash
flutter build apk --release \
  --dart-define=LIVEGO_BASE_URL=https://nobuzero.my.id/api/v2 \
  --dart-define=LIVEGO_NOBUZERO_BASE_URL=https://nobuzero.my.id/api/v2 \
  --dart-define=LIVEGO_USER_ID=ISI_USER_ID_ANDA \
  --dart-define=LIVEGO_SECRET=ISI_SECRET_ANDA
```

### 2. Run Debug
Untuk keperluan development/debugging:

```bash
flutter run --debug \
  --dart-define=LIVEGO_USER_ID=ISI_USER_ID_ANDA \
  --dart-define=LIVEGO_SECRET=ISI_SECRET_ANDA
```

## Keamanan & Kontrak API

- **Signature Dinamis**: APK men-generate signature baru untuk setiap request. Jangan menggunakan signature statis.
- **Formula Payload**: `METHOD:FULL_PATH_WITH_QUERY:TIMESTAMP`. Timestamp menggunakan unix milliseconds.
- **Larangan**:
  - Jangan commit `LIVEGO_SECRET` atau `LIVEGO_USER_ID` ke repositori GitHub.
  - Jangan mengunggah file `livego_package.txt` atau metadata paket lainnya.
  - Jangan mengirim header `X-Signature` ke URL CDN video. Header auth hanya untuk endpoint `/api/v2`.
