import os
import socket
import sys
import time
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from googleapiclient.errors import HttpError

# Set 10-minute socket timeout
socket.setdefaulttimeout(600)

KEY_PATH = r"h:\dnd-mobile\play-publisher-key.json"
PACKAGE_NAME = "com.arcane.dndai.dnd_ai"
AAB_PATH = r"h:\dnd-mobile\build\app\outputs\bundle\release\app-release.aab"
ALT_AAB_PATH = r"h:\dnd-mobile\app-release.aab"
CHANGELOG_PATH = (
    r"h:\dnd-mobile\fastlane\metadata\android\en-US\changelogs\3.txt"
    if os.path.exists(r"h:\dnd-mobile\fastlane\metadata\android\en-US\changelogs\3.txt")
    else (
        r"h:\dnd-mobile\fastlane\metadata\android\en-US\changelogs\2.txt"
        if os.path.exists(r"h:\dnd-mobile\fastlane\metadata\android\en-US\changelogs\2.txt")
        else r"h:\dnd-mobile\fastlane\metadata\android\en-US\changelogs\1.txt"
    )
)
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def read_text(file_path):
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read().strip()
    return ""


def main():
    print("=" * 60)
    print("Uploading App Bundle & Staging Production Draft Release")
    print("=" * 60)

    if not os.path.exists(KEY_PATH):
        print(f"Error: {KEY_PATH} not found")
        sys.exit(1)

    target_aab = AAB_PATH if os.path.exists(AAB_PATH) else ALT_AAB_PATH
    if not os.path.exists(target_aab):
        print(f"Error: Neither {AAB_PATH} nor {ALT_AAB_PATH} found")
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    print(f"Creating edit session for {PACKAGE_NAME}...")
    edit_req = service.edits().insert(body={}, packageName=PACKAGE_NAME)
    edit = edit_req.execute()
    edit_id = edit["id"]
    print(f"Edit ID: {edit_id}")

    try:
        file_size_mb = os.path.getsize(target_aab) / (1024 * 1024)
        print(f"Uploading App Bundle ({file_size_mb:.1f} MB) in 10MB chunks...")

        media = MediaFileUpload(
            target_aab,
            mimetype="application/octet-stream",
            chunksize=10 * 1024 * 1024,
            resumable=True,
        )
        bundle_req = service.edits().bundles().upload(
            packageName=PACKAGE_NAME, editId=edit_id, media_body=media
        )

        response = None
        retry_count = 0
        while response is None:
            try:
                status, response = bundle_req.next_chunk()
                if status:
                    print(f"  Upload Progress: {int(status.progress() * 100)}%", flush=True)
                retry_count = 0
            except Exception as chunk_err:
                retry_count += 1
                print(f"  Transient glitch ({chunk_err}), retrying chunk ({retry_count}/5)...", flush=True)
                if retry_count > 5:
                    raise chunk_err
                time.sleep(3)

        version_code = response["versionCode"]
        print(f"App Bundle uploaded successfully! Version Code: {version_code}")

        changelog = read_text(CHANGELOG_PATH)
        if not changelog:
            changelog = "Initial release of Arcane Dark."

        release_notes = [
            {
                "language": "en-US",
                "text": "Account & Data Deletion support in Settings, Firebase Performance Monitoring & Crashlytics telemetry traces, and on-device AI stability improvements.",
            },
            {
                "language": "es-419",
                "text": "Eliminación de cuenta y datos en Ajustes, monitoreo de rendimiento de Firebase y mejoras de estabilidad de IA en el dispositivo.",
            },
            {
                "language": "es-ES",
                "text": "Eliminación de cuenta y datos en Ajustes, monitoreo de rendimiento de Firebase y mejoras de estabilidad de IA en el dispositivo.",
            },
            {
                "language": "fr-FR",
                "text": "Suppression de compte et de données dans Réglages, surveillance des performances Firebase et stabilité IA améliorée.",
            },
            {
                "language": "de-DE",
                "text": "Konto- und Datenlöschung in Einstellungen, Firebase-Leistungsüberwachung und verbesserte On-Device-KI-Stabilität.",
            },
            {
                "language": "it-IT",
                "text": "Cancellazione account e dati nelle Impostazioni, monitoraggio prestazioni Firebase e stabilità IA migliorata.",
            },
            {
                "language": "ja-JP",
                "text": "設定内のアカウントおよびデータ削除機能、Firebase パフォーマンス監視、オンデバイスAIの安定性向上。",
            },
            {
                "language": "ko-KR",
                "text": "설정 내 계정 및 데이터 삭제 지원, Firebase 성능 모니터링 및 온디바이스 AI 안정성 개선.",
            },
            {
                "language": "pt-BR",
                "text": "Exclusão de conta e dados em Configurações, monitoramento de desempenho do Firebase e melhorias de estabilidade de IA.",
            },
            {
                "language": "zh-CN",
                "text": "设置中的账号与数据删除支持，Firebase 性能监控及设备端本地 AI 稳定性优化。",
            },
        ]

        print(f"Assigning to production track as DRAFT release...")
        track_body = {
            "track": "production",
            "releases": [
                {
                    "name": f"1.0.0 ({version_code})",
                    "versionCodes": [str(version_code)],
                    "status": "draft",
                    "releaseNotes": release_notes,
                }
            ],
        }

        service.edits().tracks().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            track="production",
            body=track_body,
        ).execute()
        print("Production track updated with status 'draft'.")

        print("Committing edit to Google Play Console...")
        try:
            commit_res = service.edits().commit(
                packageName=PACKAGE_NAME, editId=edit_id
            ).execute()
        except HttpError as e:
            if "changesNotSentForReview" in str(e):
                commit_res = service.edits().commit(
                    packageName=PACKAGE_NAME, editId=edit_id, changesNotSentForReview=True
                ).execute()
            else:
                raise
        print(f"SUCCESS! Committed Edit ID: {commit_res.get('id')}")
        print("=" * 60)
        print("App Bundle is now officially staged as a Production Draft!")
        print("=" * 60)

    except Exception as e:
        print(f"Error: {e}")
        try:
            service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
            print("Edit session cancelled.")
        except Exception:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
