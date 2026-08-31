import json
from google.oauth2 import service_account
from googleapiclient.discovery import build

with open("android/fastlane/play-developer-api.json") as f:
    creds_data = json.load(f)
creds = service_account.Credentials.from_service_account_info(creds_data, scopes=["https://www.googleapis.com/auth/androidpublisher"])
service = build("androidpublisher", "v3", credentials=creds)

edit = service.edits().insert(body={}, packageName="com.taucity.meowmin").execute()
listing = service.edits().listings().get(editId=edit["id"], packageName="com.taucity.meowmin", language="en-US").execute()
print(f"Title: {listing.get('title')}")
print(f"Short desc: {listing.get('shortDescription')}")
service.edits().delete(editId=edit["id"], packageName="com.taucity.meowmin").execute()
