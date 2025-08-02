#!/usr/bin/env python3

import requests
import json

def test_real_cooking_video():
    """Test with a real cooking video"""
    
    backend_url = "https://cookmaa-backend-production.up.railway.app"
    
    # Test with a real cooking video (Indian dal/lentil recipe)
    test_data = {
        "youtube_url": "https://www.youtube.com/watch?v=KTCXuWOlspc",  # Popular Indian cooking channel
        "target_servings": 4
    }
    
    print(f"🧪 Testing {backend_url}/generate-recipe with real cooking video")
    print(f"📤 Request data: {json.dumps(test_data, indent=2)}")
    
    try:
        print("⏳ Sending request (may take 1-3 minutes for video analysis)...")
        response = requests.post(
            f"{backend_url}/generate-recipe",
            json=test_data,
            headers={"Content-Type": "application/json"},
            timeout=300  # 5 minutes timeout
        )
        
        print(f"📊 Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Recipe generation successful!")
            data = response.json()
            print(f"🍽️ Recipe Title: {data.get('title', 'Unknown')}")
            print(f"👥 Servings: {data.get('servings', 'Unknown')}")
            print(f"🥘 Ingredients Count: {len(data.get('ingredients', []))}")
            print(f"📝 Steps Count: {len(data.get('steps', []))}")
            print(f"📄 Full Response: {json.dumps(data, indent=2)}")
        else:
            print(f"❌ Recipe endpoint failed: {response.status_code}")
            print(f"📄 Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Error testing endpoint: {e}")

if __name__ == "__main__":
    test_real_cooking_video()