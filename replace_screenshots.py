#!/usr/bin/env python3
"""Replace Play Store phone screenshots for all locales."""
import os
import json
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SA_KEY = "android/fastlane/play-developer-api.json"
PACKAGE = "com.taucity.meowmin"
LOCALES = ["en-US", "ar", "id", "ms", "tr-TR", "ur"]
SCREENSHOTS_DIR = "C:/Users/tau/Downloads/meowminPlaystoreScreenshots"
SCREENSHOT_FILES = [f"{i}.png" for i in range(1, 7)]

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

def main():
    creds = service_account.Credentials.from_service_account_file(
        SA_KEY, scopes=SCOPES
    )
    creds = creds.with_subject("tauqeer1040@gmail.com")
    service = build("androidpublisher", "v3", credentials=creds)

    # Create a single edit for all operations
    edit = service.edits().insert(
        body={"id": "screenshot-replace-" + str(int(__import__("time").time()))},
        packageName=PACKAGE,
    ).execute()
    edit_id = edit["id"]
    print(f"Created edit: {edit_id}")

    try:
        for locale in LOCALES:
            print(f"\n--- {locale} ---")

            # List existing screenshots
            try:
                existing = service.edits().images().list(
                    editId=edit_id,
                    packageName=PACKAGE,
                    imageType="phoneScreenshots",
                    language=locale,
                ).execute()
                images = existing.get("images", [])
                print(f"  Found {len(images)} existing screenshots")
            except Exception as e:
                print(f"  Error listing: {e}")
                images = []

            # Delete existing screenshots
            for img in images:
                try:
                    service.edits().images().delete(
                        editId=edit_id,
                        packageName=PACKAGE,
                        imageType="phoneScreenshots",
                        language=locale,
                        imageId=img["id"],
                    ).execute()
                    print(f"  Deleted: {img['id']}")
                except Exception as e:
                    print(f"  Error deleting {img['id']}: {e}")

            # Upload new screenshots
            for fname in SCREENSHOT_FILES:
                fpath = os.path.join(SCREENSHOTS_DIR, fname)
                if not os.path.exists(fpath):
                    print(f"  SKIP: {fpath} not found")
                    continue

                media = MediaFileUpload(
                    fpath,
                    mimetype="image/png",
                    resumable=True,
                )
                try:
                    result = service.edits().images().upload(
                        editId=edit_id,
                        packageName=PACKAGE,
                        imageType="phoneScreenshots",
                        language=locale,
                        media_body=media,
                    ).execute()
                    print(f"  Uploaded: {fname} -> {result.get('image', {}).get('id', 'ok')}")
                except Exception as e:
                    print(f"  Error uploading {fname}: {e}")

        # Commit
        print("\nCommitting edit...")
        service.edits().commit(
            editId=edit_id,
            packageName=PACKAGE,
        ).execute()
        print("Done! Screenshots replaced.")

    except Exception as e:
        print(f"\nError during operations: {e}")
        print("Discarding edit...")
        service.edits().delete(
            editId=edit_id,
            packageName=PACKAGE,
        ).execute()
        raise

if __name__ == "__main__":
    main()
