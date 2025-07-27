#!/usr/bin/env python3
"""
Test script for Gemini integration with CookMaa backend
"""

import requests
import json
import time

# Test configuration
BACKEND_URL = "https://cookmaa-backend-production.up.railway.app"
LOCAL_URL = "http://localhost:8000"

# Test YouTube URLs (short cooking videos work best)
TEST_URLS = [
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ",  # Replace with actual cooking video
    "https://youtu.be/dQw4w9WgXcQ"  # Replace with actual cooking video
]

def test_endpoint(base_url: str, test_url: str):
    """Test the /generate-recipe endpoint"""
    
    print(f"\n🧪 Testing {base_url} with URL: {test_url}")
    
    payload = {
        "youtube_url": test_url,
        "target_servings": 4
    }
    
    try:
        print("📤 Sending request...")
        start_time = time.time()
        
        response = requests.post(
            f"{base_url}/generate-recipe",
            json=payload,
            timeout=300  # 5 minutes timeout
        )
        
        end_time = time.time()
        duration = end_time - start_time
        
        print(f"⏱️  Response time: {duration:.2f} seconds")
        print(f"📊 Status code: {response.status_code}")
        
        if response.status_code == 200:
            recipe_data = response.json()
            print(f"✅ Success! Recipe: {recipe_data.get('title', 'Unknown')}")
            print(f"🥘 Cuisine: {recipe_data.get('cuisine', 'Unknown')}")
            print(f"👥 Servings: {recipe_data.get('servings', 'Unknown')}")
            print(f"📝 Steps: {len(recipe_data.get('steps', []))}")
            print(f"🛒 Ingredients: {len(recipe_data.get('ingredients', []))}")
            
            # Show first few ingredients
            ingredients = recipe_data.get('ingredients', [])[:3]
            for i, ingredient in enumerate(ingredients, 1):
                print(f"   {i}. {ingredient.get('amount', '')} {ingredient.get('unit', '')} {ingredient.get('name', '')}")
                
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"📄 Response: {response.text}")
            
    except requests.exceptions.Timeout:
        print("⏰ Request timed out (video analysis may take a while)")
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

def test_health_check(base_url: str):
    """Test the health check endpoint"""
    
    print(f"\n❤️  Testing health check: {base_url}/health")
    
    try:
        response = requests.get(f"{base_url}/health", timeout=10)
        
        if response.status_code == 200:
            print("✅ Health check passed")
            print(f"📄 Response: {response.json()}")
        else:
            print(f"❌ Health check failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Health check error: {e}")

if __name__ == "__main__":
    print("🚀 CookMaa Backend Integration Test")
    print("=" * 50)
    
    # Test health check for Railway deployment
    test_health_check(BACKEND_URL)
    
    # Test recipe generation (start with Railway backend)
    print(f"\n🎬 Testing recipe generation...")
    print("Note: Replace test URLs with actual cooking videos")
    
    # For now, just test with the first URL to verify the endpoint structure
    test_endpoint(BACKEND_URL, TEST_URLS[0])
    
    print(f"\n✨ Test complete!")
    print("💡 To test with real cooking videos:")
    print("   1. Replace TEST_URLS with actual YouTube cooking video URLs")
    print("   2. Ensure the Railway deployment has GEMINI_API_KEY environment variable set")
    print("   3. Monitor Railway logs for detailed analysis progress")