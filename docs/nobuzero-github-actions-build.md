# Nobuzero GitHub Actions Build

Runtime API final Nobuzero adalah `https://nobuzero.my.id/api/v2`.

## Secrets wajib

Isi GitHub Actions Secrets atau Codex Cloud Secrets berikut sebelum menjalankan build APK release:

- `LIVEGO_BASE_URL`
- `LIVEGO_NOBUZERO_BASE_URL`
- `LIVEGO_USER_ID`
- `LIVEGO_SECRET`

Credential test hanya untuk uji internal. Jangan menulis secret asli ke source, docs, prompt, log, issue, atau PR.

## Command release

Workflow memakai secret melalui `--dart-define`:

```bash
flutter build apk --release \
  --dart-define=LIVEGO_BASE_URL="${{ secrets.LIVEGO_BASE_URL }}" \
  --dart-define=LIVEGO_NOBUZERO_BASE_URL="${{ secrets.LIVEGO_NOBUZERO_BASE_URL }}" \
  --dart-define=LIVEGO_USER_ID="${{ secrets.LIVEGO_USER_ID }}" \
  --dart-define=LIVEGO_SECRET="${{ secrets.LIVEGO_SECRET }}"
```

Workflow wajib gagal jika salah satu secret kosong dan tidak mencetak nilai secret ke log.

## Artifact internal

APK hasil uji membawa credential dari secrets karena aplikasi masih tahap uji internal. APK di-upload sebagai GitHub Actions artifact internal, bukan GitHub Release public. Jangan publikasikan artifact ini.

Setelah test selesai, owner akan menonaktifkan user test dari Admin UI. Untuk final release nanti, `BASE URL` bisa diganti ke Worker dan secret diganti baru.

## File yang tidak boleh di-commit

Jangan commit credential, APK/AAB, `.env`, atau file package Admin UI seperti `livego_package.txt`, `livego_package*.md`, `livego_package*.json`, dan `livego_package*.zip`.
