# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CookMaa is an AI-powered cooking assistant iOS app that converts YouTube cooking videos into interactive, voice-guided step-by-step recipes with multilingual AI assistance and visual Q&A capabilities. Built with SwiftUI targeting iOS 18.5+.

## Core Technology Stack

### Primary Components
- **Pipecat**: Open-source voice AI orchestration framework
- **Moondream**: Lightweight vision-language model for image analysis  
- **Gemini 1.5 Flash**: Primary LLM for recipe generation and conversation
- **iOS Swift**: Native app development with SwiftUI
- **Railway**: $5/month hosting for backend services

## Complete User Flow

### 1. Recipe Generation Flow
```
User pastes YouTube URL → Gemini 1.5 Flash video analysis → Structured recipe → Display on iOS
```

### 2. Interactive Cooking Flow
```
iOS displays step text → User says "Hey Kukma, [command]" → Pipecat STT → Gemini processes → Pipecat TTS → User hears response
```

### 3. Visual Q&A Flow
```
User says "Hey Kukma, I have a question" → Camera auto-opens → User shows food + asks question → Moondream analyzes image → Gemini contextualizes → Pipecat speaks answer
```

## Repository Structure

**CRITICAL: This project uses TWO SEPARATE Git repositories:**

### Main Repository: CookMaa iOS App
- **Location**: `/Users/sudhanvaacharya/desktop/code projects/cookmaa`
- **Remote**: `https://github.com/Team-NCP/CookMa.git`
- **Contains**: 
  - iOS SwiftUI app (`CookMaa/`, `CookMaaTests/`, `CookMaaUITests/`)
  - Xcode project files (`CookMaa.xcodeproj/`)
  - Integration test scripts (`test_*.py`)
  - This CLAUDE.md file
- **Git Operations**: Standard git commands from root directory

### Backend Repository: Python Voice Assistant
- **Location**: `/Users/sudhanvaacharya/desktop/code projects/cookmaa/backend/`
- **Remote**: `https://github.com/Team-NCP/CookMaa-Backend.git`
- **Contains**:
  - Python FastAPI server (`cooking_voice_assistant.py`)
  - Docker deployment (`Dockerfile`, `railway.json`)
  - Python dependencies (`requirements.txt`)
  - Backend documentation (`README.md`)
- **Git Operations**: Must `cd backend/` before git commands

### Repository Management Rules
```bash
# For iOS app changes (main repo)
git add CookMaa/ CookMaaTests/ *.swift *.py CLAUDE.md
git commit -m "iOS app changes"
git push  # pushes to CookMa.git

# For backend changes (backend repo)
cd backend/
git add requirements.txt Dockerfile *.py
git commit -m "Backend changes"
git push  # pushes to CookMaa-Backend.git
cd ..

# Railway deploys from: CookMaa-Backend.git
# iOS app references: CookMa.git
```

**⚠️ NEVER mix backend and frontend changes in the same commit!**

## Development Commands

### Building and Running
- **Build the project**: Open `CookMaa.xcodeproj` in Xcode and use Cmd+B to build
- **Run the app**: Use Cmd+R in Xcode or select a simulator/device and press the play button
- **Run tests**: Use Cmd+U in Xcode to run all tests, or use the Test navigator to run specific test suites

### Testing
- **Unit tests**: Located in `CookMaaTests/` directory, uses the new Swift Testing framework
- **UI tests**: Located in `CookMaaUITests/` directory for end-to-end testing
- **Single test**: Use the diamond icon next to individual test methods in Xcode to run specific tests

## Technical Architecture

### Backend Services (Railway - $5/month)
```python
# Voice Pipeline Service
class CookingVoiceAssistant:
    def __init__(self):
        self.stt = DeepgramSTTService()  # Speech-to-text
        self.tts = ElevenLabsTTSService()  # Text-to-speech
        self.llm = GeminiLLMService()  # Conversation brain
        self.vision = MoondreamVision()  # Image analysis
        
    async def handle_wake_word(self, audio):
        # "Hey Kukma" detection and processing
        
    async def handle_visual_question(self, image, audio):
        # Camera + voice question processing
```

### iOS App Components
```swift
// Main cooking interface
class CookingViewController {
    // Dual interface: visual steps + voice interaction
    // Wake word detection with Apple Speech Recognition
    // Camera integration for visual questions
    // Real-time audio streaming with Pipecat
}

// Recipe generation service
class RecipeService {
    // Direct YouTube URL → Gemini 1.5 Flash video analysis
    // Structured recipe parsing and storage
}
```

## Voice Pipeline Configuration

### Recommended Pipecat Setup
```python
# STT: Deepgram (excellent for kitchen noise, multilingual)
stt = DeepgramSTTService(
    model="nova-2-conversationalai",
    detect_language=True  # Auto English/Kannada switching
)

# TTS: ElevenLabs (natural voice quality, multilingual)
tts = ElevenLabsTTSService(
    voice_id="chosen_voice",
    model="eleven_multilingual_v2"
)

# LLM: Gemini 1.5 Flash (recipe intelligence)
llm = GeminiLLMService(model="gemini-1.5-flash")
```

### Alternative Budget Setup
```python
# Budget-friendly alternatives
stt = GroqSTTService(model="whisper-large-v3")  # Cheaper
tts = PlayHTService(voice_id="budget_voice")     # Cheaper
llm = GeminiLLMService(model="gemini-1.5-flash")  # Same (free)
```

## Key Features

### 1. Direct Video Analysis
- No transcript extraction needed (eliminates failure points)
- Gemini 1.5 Flash analyzes YouTube videos directly
- Understands both visual cues and spoken instructions
- Extracts ingredients, steps, timing, techniques

### 2. Wake Word System
- "Hey Kukma, next step" - Move to next cooking step
- "Hey Kukma, repeat that" - Repeat current instruction  
- "Hey Kukma, I have a question" - Auto-open camera for visual Q&A
- "Hey Kukma, how long should this take?" - Contextual timing info

### 3. Dual Interface Design
- Visual: Concise step text on screen
- Audio: Detailed humanized explanations via Pipecat
- Non-intrusive: Voice assistant speaks once then goes silent
- Hands-free: Voice commands work with messy hands

### 4. Intelligent Visual Q&A
- Camera auto-opens on question commands
- Moondream analyzes food images locally (~100ms)
- Gemini contextualizes with current recipe step
- Natural voice responses about cooking progress

### 5. Multilingual Support
- Auto-detection between English and Kannada
- Natural code-switching within conversations
- Cultural cooking context understanding
- Traditional cooking method recognition

## Cost Analysis

### Free Tier Coverage (Personal Use)
```
Gemini 1.5 Flash Video Analysis:
- Daily limit: 1,500 requests
- Your usage: 1-3 videos per day
- Result: 100% FREE for personal use

Complete cooking session tokens:
- Recipe generation: ~180,000 tokens
- Voice interactions: ~5,000 tokens
- Image contextualization: ~1,200 tokens
- Total per session: ~186,000 tokens
- Daily capacity: 60+ complete sessions
- Your usage: 1-3 sessions per day
```

### Paid Components (When Scaling)
```
Video Analysis (if exceeding free tier):
- Cost: ~$0.028 per 10-minute cooking video
- 100 videos/month: $2.80

Voice Pipeline (Pipecat + providers):
Premium setup: ~$0.50 per cooking session
Budget setup: ~$0.15 per cooking session
Monthly (20 sessions): $3-10

Railway Hosting: $5/month

Total for heavy personal use: $8-18/month
Total for normal personal use: $5/month (just hosting)
```

## Implementation Strategy

### Phase 1: Core Recipe Generation
1. iOS app with YouTube URL input
2. Gemini 1.5 Flash video analysis integration
3. Recipe display with ingredient management
4. Basic step-by-step navigation

### Phase 2: Voice Integration  
1. Deploy Pipecat on Railway
2. Wake word detection ("Hey Kukma")
3. Voice command processing
4. Text-to-speech responses

### Phase 3: Visual Intelligence
1. Moondream deployment on Railway
2. Camera auto-launch on question commands
3. Image analysis + recipe contextualization
4. Integrated voice responses

### Phase 4: Multilingual Support
1. Language detection in voice pipeline
2. Dynamic English/Kannada switching
3. Cultural cooking context integration
4. Traditional cooking method understanding

### Phase 5: Optimization
1. Local caching for common responses
2. Usage analytics and cost monitoring
3. Performance tuning for real-time voice
4. User experience refinements

## Current Project Structure
```
CookMaa/                    # Main app source code
├── CookMaaApp.swift       # App entry point with @main
├── ContentView.swift      # Main content view (currently displays "Hello, world!")
└── Assets.xcassets/       # App icons and other assets

CookMaaTests/              # Unit tests using Swift Testing framework
CookMaaUITests/            # UI/integration tests
```

## Planned File Structure

```
CookMaa/
├── iOS/
│   ├── ViewControllers/
│   │   ├── RecipeInputViewController.swift
│   │   ├── IngredientReviewViewController.swift
│   │   └── CookingViewController.swift
│   ├── Services/
│   │   ├── RecipeService.swift
│   │   ├── VoiceService.swift
│   │   └── CameraService.swift
│   └── Models/
│       ├── Recipe.swift
│       ├── Ingredient.swift
│       └── CookingStep.swift
├── Backend/
│   ├── voice_assistant.py
│   ├── recipe_service.py
│   ├── moondream_vision.py
│   └── requirements.txt
├── Deployment/
│   ├── Dockerfile
│   ├── railway.json
│   └── docker-compose.yml
└── Documentation/
    ├── API_Documentation.md
    ├── Setup_Guide.md
    └── Cost_Analysis.md
```

### Technology Stack
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI with iOS 18.5+ deployment target
- **Testing**: Swift Testing framework (modern replacement for XCTest)
- **Architecture**: Standard SwiftUI app with `@main` entry point
- **Build System**: Xcode project file (.xcodeproj)
- **Backend**: Python with Pipecat, Moondream, Gemini 1.5 Flash
- **Hosting**: Railway ($5/month)

### Key Configuration
- **Bundle ID**: NCPUDP.CookMaa
- **Deployment Target**: iOS 18.5
- **Supported Devices**: iPhone and iPad (TARGETED_DEVICE_FAMILY = "1,2")
- **SwiftUI Previews**: Enabled (ENABLE_PREVIEWS = YES)

## Environment Variables

```env
# Gemini
GEMINI_API_KEY=your_gemini_key

# Voice Pipeline
DEEPGRAM_API_KEY=your_deepgram_key
ELEVENLABS_API_KEY=your_elevenlabs_key

# Alternative Budget Options
GROQ_API_KEY=your_groq_key
PLAYHT_API_KEY=your_playht_key

# Deployment
RAILWAY_TOKEN=your_railway_token
```

## Key Technical Decisions

### Why Gemini 1.5 Flash Video Analysis?
- 100% success rate (no transcript failures)
- Understands both visual and audio cues
- Superior recipe quality with technique recognition
- Free tier covers personal usage indefinitely

### Why Pipecat over VAPI?
- Open source (full control)
- 90% cost reduction vs VAPI
- Better provider flexibility
- Real-time optimization built-in

### Why Moondream for Vision?
- Lightning fast (~100ms vs 2-3s for cloud APIs)
- Runs locally (privacy + no API costs)
- Perfect for food/cooking scene understanding
- Unlimited image analysis

### Why Railway Hosting?
- Perfect specs for ML models (8GB RAM)
- Simple deployment from GitHub
- Built-in SSL and domains
- $5/month vs $50-100 for AWS ECS

## Development Notes

- Project is currently in early development stage with basic "Hello, world!" implementation
- Uses the modern Swift Testing framework instead of XCTest
- Project uses automatic code signing
- SwiftUI previews are enabled for rapid development
- Backend services will be deployed to Railway for cost-effective hosting
- Focus on multilingual support (English/Kannada) from the beginning