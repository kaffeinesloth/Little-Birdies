"""
test_real_api.py — Test với Google API key thật.

Chạy: python test_real_api.py
"""
import asyncio
from dotenv import load_dotenv

load_dotenv()  # Đọc từ .env

from config import settings
from agent.intent_classifier import IntentClassifier

TESTS = [
    ("Giá áo polo bao nhiêu?",          "GENERAL_FAQ"),
    ("Hàng giao bị lỗi, tôi muốn đổi!", "COMPLAINT"),
    ("LỪA ĐẢO!!! HOÀN TIỀN NGAY!!!",   "ANGRY"),
]

async def main():
    if not settings.google_api_key:
        print("❌ Chưa có GOOGLE_API_KEY trong .env")
        return

    clf = IntentClassifier(api_key=settings.google_api_key, model_name=settings.intent_model)
    print(f"Model: {settings.intent_model}\n")

    for msg, expected in TESTS:
        result = await clf.classify(msg)
        ok = "✅" if result.intent.value == expected else "❌"
        print(f"{ok} '{msg[:40]}'")
        print(f"   → {result.intent.value} (confidence={result.confidence:.2f}, urgency={result.urgency_level})")

asyncio.run(main())
