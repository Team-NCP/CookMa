#!/usr/bin/env python3

import requests
import json

def test_recipe_endpoint():
    """Test the /generate-recipe endpoint"""
    
    backend_url = "https://cookmaa-backend-production.up.railway.app"
    
    # Test data
    test_data = {
        "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "target_servings": 6
    }
    
    print(f"🧪 Testing {backend_url}/generate-recipe")
    print(f"📤 Request data: {json.dumps(test_data, indent=2)}")
    
    try:
        response = requests.post(
            f"{backend_url}/generate-recipe",
            json=test_data,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        print(f"📊 Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Recipe endpoint working!")
            data = response.json()
            print(f"📄 Response: {json.dumps(data, indent=2)}")
        else:
            print(f"❌ Recipe endpoint failed: {response.status_code}")
            print(f"📄 Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Error testing endpoint: {e}")

if __name__ == "__main__":
    test_recipe_endpoint()