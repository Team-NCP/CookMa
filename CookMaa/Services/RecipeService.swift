//
//  RecipeService.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation

@MainActor
class RecipeService: ObservableObject {
    @Published var isLoading = false
    @Published var error: RecipeError?
    
    private let geminiAPIKey: String
    private var baseRecipeCache: [String: Recipe] = [:] // Cache base recipes without scaling
    
    init() {
        guard let apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              apiKey != "YOUR_GEMINI_API_KEY_HERE",
              !apiKey.isEmpty else {
            fatalError("Please add your Gemini API key to Info.plist. Replace 'YOUR_GEMINI_API_KEY_HERE' with your actual API key from https://makersuite.google.com/app/apikey")
        }
        self.geminiAPIKey = apiKey
    }
    
    func generateRecipe(from youtubeURL: String, forServings targetServings: Int = 4) async throws -> Recipe {
        print("🎬 Starting recipe generation for URL: \(youtubeURL)")
        
        // Check if we have the base recipe cached
        if let baseRecipe = baseRecipeCache[youtubeURL] {
            print("🎯 Found cached base recipe, applying local scaling to \(targetServings) servings")
            return scaleRecipeLocally(baseRecipe, to: targetServings)
        }
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
            print("🏁 Recipe generation completed (loading = false)")
        }
        
        guard isValidYouTubeURL(youtubeURL) else {
            print("❌ Invalid YouTube URL provided")
            let error = RecipeError.invalidURL
            self.error = error
            throw error
        }
        
        print("✅ YouTube URL validation passed")
        
        do {
            // Get base recipe from Gemini (analyze video to understand original serving size)
            let baseRecipe = try await analyzeVideoWithGemini(youtubeURL: youtubeURL, targetServings: targetServings)
            
            // Cache the base recipe
            baseRecipeCache[youtubeURL] = baseRecipe
            print("💾 Cached base recipe for future scaling")
            print("🎉 Recipe generation successful!")
            
            // If target servings match original, return as-is, otherwise scale locally
            return baseRecipe
        } catch {
            print("❌ Recipe generation failed: \(error)")
            let recipeError = error as? RecipeError ?? RecipeError.analysisFailure(error.localizedDescription)
            self.error = recipeError
            throw recipeError
        }
    }
    
    private func isValidYouTubeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let host = url.host?.lowercased()
        return host == "youtube.com" || host == "www.youtube.com" || host == "youtu.be" || host == "m.youtube.com"
    }
    
    private func scaleRecipeLocally(_ baseRecipe: Recipe, to targetServings: Int) -> Recipe {
        print("🔢 Scaling recipe locally from \(baseRecipe.servings) to \(targetServings) servings")
        
        let scalingFactor = Double(targetServings) / Double(baseRecipe.servings)
        
        let scaledIngredients = baseRecipe.ingredients.map { ingredient in
            scaleIngredient(ingredient, by: scalingFactor)
        }
        
        return Recipe(
            title: baseRecipe.title,
            youtubeURL: baseRecipe.youtubeURL,
            description: baseRecipe.description,
            cuisine: baseRecipe.cuisine,
            difficulty: baseRecipe.difficulty,
            totalTime: baseRecipe.totalTime,
            servings: targetServings,
            ingredients: scaledIngredients,
            steps: baseRecipe.steps, // Steps remain the same
            chefsWisdom: baseRecipe.chefsWisdom,
            scalingNotes: baseRecipe.scalingNotes,
            originalServings: baseRecipe.originalServings
        )
    }
    
    private func scaleIngredient(_ ingredient: Ingredient, by factor: Double) -> Ingredient {
        // Apply cooking knowledge for scaling
        let scaledAmount = applyIngredientScalingRules(
            ingredient: ingredient,
            originalAmount: ingredient.amount,
            scalingFactor: factor
        )
        
        return Ingredient(
            name: ingredient.name,
            amount: scaledAmount,
            unit: ingredient.unit,
            notes: ingredient.notes,
            isAvailable: ingredient.isAvailable
        )
    }
    
    private func applyIngredientScalingRules(ingredient: Ingredient, originalAmount: String, scalingFactor: Double) -> String {
        let ingredientName = ingredient.name.lowercased()
        
        // Parse original amount
        guard let numericAmount = extractNumericAmount(from: originalAmount) else {
            return originalAmount // If we can't parse, return original
        }
        
        var scaledAmount = numericAmount * scalingFactor
        
        // Apply ingredient-specific scaling rules
        if ingredientName.contains("rice") || ingredientName.contains("pasta") {
            // Rice/pasta: Use standard ratios (1/2 cup per person)
            scaledAmount = Double(Int(scalingFactor * Double(extractServingsFromRecipe()))) * 0.5
        } else if ingredientName.contains("salt") {
            // Salt: Scale very conservatively
            scaledAmount = numericAmount * min(scalingFactor, 1.5)
        } else if ingredientName.contains("spice") || ingredientName.contains("chili") || ingredientName.contains("pepper") {
            // Spices: Scale conservatively
            scaledAmount = numericAmount * pow(scalingFactor, 0.7)
        } else if ingredientName.contains("oil") || ingredientName.contains("ghee") {
            // Fats: Scale moderately
            scaledAmount = numericAmount * pow(scalingFactor, 0.8)
        }
        
        // Round to practical measurements
        return formatPracticalAmount(scaledAmount, unit: ingredient.unit)
    }
    
    private func extractNumericAmount(from amount: String) -> Double? {
        // Extract number from strings like "2", "1.5", "1/2", "2 1/4"
        let cleanAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle fractions like "1/2"
        if cleanAmount.contains("/") {
            let parts = cleanAmount.components(separatedBy: "/")
            if parts.count == 2,
               let numerator = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
               let denominator = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                return numerator / denominator
            }
        }
        
        // Handle regular numbers
        return Double(cleanAmount.components(separatedBy: CharacterSet.letters.union(.whitespaces)).first ?? "")
    }
    
    private func extractServingsFromRecipe() -> Int {
        return 4 // Default fallback, should use actual recipe servings
    }
    
    private func formatPracticalAmount(_ amount: Double, unit: String?) -> String {
        // Round to practical cooking measurements
        if amount < 0.125 {
            return "pinch"
        } else if amount < 0.25 {
            return "1/8"
        } else if amount < 0.375 {
            return "1/4"
        } else if amount < 0.625 {
            return "1/2"
        } else if amount < 0.875 {
            return "3/4"
        } else if amount < 1.5 {
            return "1"
        } else {
            return String(format: "%.1f", amount)
        }
    }
    
    private func analyzeVideoWithGemini(youtubeURL: String, targetServings: Int) async throws -> Recipe {
        print("🔄 Starting Gemini API analysis for URL: \(youtubeURL)")
        
        let prompt = """
        Watch this cooking video carefully and provide a complete recipe. Act as an experienced chef teaching someone in your kitchen. Pay close attention to every detail - ingredients, techniques, timing, visual cues, and any tips or cultural context shared.

        CRITICAL: First identify how many people this recipe actually serves by watching the video context, portion sizes, and any mentions by the chef.

        INTELLIGENT SCALING APPROACH:
        - DO NOT assume the recipe serves 4 people
        - Identify actual serving size from video context (pot size, portions shown, chef's comments)
        - Use COOKING KNOWLEDGE for scaling, not just mathematical proportions
        - Apply ingredient-specific scaling rules:
          * Rice: ~1/2 cup (100g) uncooked rice per person
          * Pasta: ~100g dried pasta per person  
          * Lentils/Dal: ~1/4 cup dried lentils per person
          * Vegetables: Scale more generously (people like more veggies)
          * Spices: Scale conservatively (start with less, can add more)
          * Salt: Scale very conservatively 
          * Oil/Ghee: Scale moderately (health consideration)
        - Round to practical measurements (1/2, 1/4, 3/4 cups, not complex fractions)

        Structure your response EXACTLY as follows with these headers:

        TITLE: [Exact dish name from video]

        DESCRIPTION: [Brief description - cuisine, difficulty, time, cultural context for \(targetServings) people]

        INGREDIENTS:
        - [Ingredient 1 with amount, unit, preparation notes]
        - [Ingredient 2 with amount, unit, preparation notes]
        - [Continue for all ingredients...]

        STEPS:
        1. [Very detailed step with exact measurements - like "Take 1 cup basmati rice, rinse 3 times until water runs clear, then add to your cooking pot"]
        2. [Next detailed step with specific actions and measurements]
        3. [Continue with detailed, actionable steps...]

        CHEF_WISDOM: [Rich context for voice assistant - tips, cultural notes, variations, storage]

        SCALING_NOTES: Original serves [X] people, scaled to \(targetServings) using cooking knowledge

        Use simple headers (TITLE:, DESCRIPTION:, INGREDIENTS:, STEPS:, CHEF_WISDOM:, SCALING_NOTES:) for easy parsing.
        """
        
        print("📝 Generated prompt for Gemini API")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ],
                        [
                            "file_data": [
                                "mime_type": "video/*",
                                "file_uri": youtubeURL
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 4096
            ]
        ]
        
        print("🔗 Creating API request to Gemini")
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(geminiAPIKey)") else {
            print("❌ Failed to create API URL")
            throw RecipeError.networkError("Invalid API URL")
        }
        
        print("✅ API URL created successfully")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes for video analysis
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📦 Request body serialized successfully")
        } catch {
            print("❌ Failed to serialize request body: \(error)")
            throw RecipeError.networkError("Failed to serialize request: \(error.localizedDescription)")
        }
        
        print("🚀 Sending request to Gemini API...")
        print("⏳ Video analysis may take 1-3 minutes...")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
            print("📨 Received response from Gemini API")
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                print("⏰ Request timed out - video analysis took too long")
                throw RecipeError.networkError("Video analysis timed out. Please try with a shorter video or try again later.")
            } else {
                print("❌ Network error: \(error)")
                throw RecipeError.networkError("Network error: \(error.localizedDescription)")
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Failed to cast response to HTTPURLResponse")
            throw RecipeError.networkError("Invalid response type")
        }
        
        print("📊 HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("❌ API request failed with status \(httpResponse.statusCode)")
            print("❌ Response body: \(responseString)")
            throw RecipeError.networkError("API request failed with status \(httpResponse.statusCode): \(responseString)")
        }
        
        print("✅ API request successful")
        
        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            print("✅ Successfully decoded Gemini response")
        } catch let decodingError {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("❌ Failed to decode Gemini response: \(decodingError)")
            print("📄 Raw response: \(responseString)")
            throw RecipeError.analysisFailure("Failed to decode response: \(decodingError.localizedDescription)")
        }
        
        guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
            print("❌ No content found in Gemini response")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 Full response: \(responseString)")
            throw RecipeError.analysisFailure("No content in response")
        }
        
        print("📄 Gemini response content: \(content)")
        
        let recipeData = try parseNaturalLanguageRecipe(from: content)
        print("✅ Successfully parsed natural language recipe")
        
        return Recipe(
            title: recipeData.title,
            youtubeURL: youtubeURL,
            description: recipeData.description,
            cuisine: recipeData.cuisine,
            difficulty: DifficultyLevel(rawValue: recipeData.difficulty) ?? .medium,
            totalTime: TimeInterval(recipeData.totalTime),
            servings: recipeData.servings,
            ingredients: recipeData.ingredients.map { ingredientData -> Ingredient in
                Ingredient(
                    name: ingredientData.name,
                    amount: ingredientData.amount,
                    unit: ingredientData.unit,
                    notes: ingredientData.notes
                )
            },
            steps: recipeData.steps.map { stepData -> CookingStep in
                CookingStep(
                    stepNumber: stepData.stepNumber,
                    instruction: stepData.instruction,
                    detailedExplanation: stepData.detailedExplanation,
                    estimatedTime: stepData.estimatedTime.map(TimeInterval.init),
                    temperature: stepData.temperature,
                    technique: stepData.technique
                )
            },
            chefsWisdom: recipeData.chefsWisdom,
            scalingNotes: recipeData.scalingNotes,
            originalServings: recipeData.originalServings
        )
    }
    
    private func parseNaturalLanguageRecipe(from content: String) throws -> RecipeData {
        print("🔄 Starting to parse natural language recipe")
        print("📄 Raw content length: \(content.count) characters")
        
        let sections = extractSections(from: content)
        
        let title = sections["TITLE"] ?? "Untitled Recipe"
        let description = sections["DESCRIPTION"]
        let ingredients = parseIngredients(from: sections["INGREDIENTS"] ?? "")
        let steps = parseSteps(from: sections["STEPS"] ?? "")
        
        print("✅ Successfully parsed natural language recipe")
        print("📋 Recipe title: \(title)")
        print("📋 Ingredients count: \(ingredients.count)")
        print("📋 Steps count: \(steps.count)")
        
        return RecipeData(
            title: title,
            description: description,
            cuisine: extractCuisine(from: description ?? ""),
            difficulty: extractDifficulty(from: description ?? ""),
            totalTime: extractTotalTime(from: description ?? ""),
            servings: extractServings(from: description ?? ""),
            ingredients: ingredients,
            steps: steps,
            chefsWisdom: sections["CHEF_WISDOM"],
            scalingNotes: sections["SCALING_NOTES"],
            originalServings: extractOriginalServings(from: sections["SCALING_NOTES"] ?? "")
        )
    }
    
    private func extractSections(from content: String) -> [String: String] {
        print("🔍 Extracting sections using simple headers")
        
        var sections: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        var currentSection: String?
        var currentContent: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for headers like "TITLE:", "INGREDIENTS:", etc.
            if let colonIndex = trimmedLine.firstIndex(of: ":"), 
               trimmedLine.prefix(upTo: colonIndex).allSatisfy({ $0.isLetter || $0 == "_" }) {
                
                // Save previous section
                if let section = currentSection, !currentContent.isEmpty {
                    sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Start new section
                currentSection = String(trimmedLine.prefix(upTo: colonIndex))
                let afterColon = String(trimmedLine.suffix(from: trimmedLine.index(after: colonIndex))).trimmingCharacters(in: .whitespacesAndNewlines)
                currentContent = afterColon.isEmpty ? [] : [afterColon]
                
            } else if !trimmedLine.isEmpty {
                currentContent.append(trimmedLine)
            }
        }
        
        // Save last section
        if let section = currentSection, !currentContent.isEmpty {
            sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        print("📋 Found sections: \(sections.keys.joined(separator: ", "))")
        return sections
    }
    
    private func extractTitle(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        
        // Fallback: Look for title in the response content (after "## " but before next section)
        let sections = extractSections(from: content)
        
        // Check if there's a standalone title line
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("## ") && !trimmedLine.contains("RECIPE TITLE") && !trimmedLine.contains("ABOUT") && !trimmedLine.contains("INGREDIENTS") && !trimmedLine.contains("COOKING") && !trimmedLine.contains("CHEF'S") {
                return String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return "Untitled Recipe"
    }
    
    private func extractDescription(from content: String) -> String? {
        return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content
    }
    
    private func extractCuisine(from content: String) -> String? {
        // Look for cuisine patterns in the description
        let cuisineKeywords = ["indian", "italian", "chinese", "mexican", "thai", "japanese", "french", "american", "mediterranean"]
        let lowercased = content.lowercased()
        
        for keyword in cuisineKeywords {
            if lowercased.contains(keyword) {
                return keyword.capitalized
            }
        }
        return nil
    }
    
    private func extractDifficulty(from content: String) -> String {
        let lowercased = content.lowercased()
        if lowercased.contains("easy") || lowercased.contains("simple") || lowercased.contains("beginner") {
            return "Easy"
        } else if lowercased.contains("hard") || lowercased.contains("difficult") || lowercased.contains("expert") || lowercased.contains("advanced") {
            return "Hard"
        } else {
            return "Medium"
        }
    }
    
    private func extractTotalTime(from content: String) -> Int {
        // Extract time patterns like "30 minutes", "1 hour", "45 mins"
        do {
            let regex = try NSRegularExpression(pattern: #"(\d+)\s*(hour|hr|minute|min)"#, options: .caseInsensitive)
            let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            
            var totalMinutes = 0
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: content),
                   let unitRange = Range(match.range(at: 2), in: content),
                   let number = Int(content[numberRange]) {
                    let unit = content[unitRange].lowercased()
                    if unit.contains("hour") || unit.contains("hr") {
                        totalMinutes += number * 60
                    } else {
                        totalMinutes += number
                    }
                }
            }
            
            return totalMinutes > 0 ? totalMinutes * 60 : 1800 // Convert to seconds, default 30 min
        } catch {
            return 1800 // Default 30 minutes
        }
    }
    
    private func extractServings(from content: String) -> Int {
        // Extract serving patterns like "serves 4", "4 people", "6 servings"
        do {
            let regex = try NSRegularExpression(pattern: #"(\d+)\s*(people|serving|portion)"#, options: .caseInsensitive)
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
               let numberRange = Range(match.range(at: 1), in: content),
               let servings = Int(content[numberRange]) {
                return servings
            }
        } catch {}
        
        return 4 // Default servings
    }
    
    private func parseIngredients(from content: String) -> [IngredientData] {
        print("🥕 Parsing ingredients from natural language")
        
        let lines = content.components(separatedBy: .newlines)
        var ingredients: [IngredientData] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty && (trimmed.hasPrefix("-") || trimmed.hasPrefix("•")) else { continue }
            
            let ingredient = parseIngredientLine(trimmed)
            if !ingredient.name.isEmpty {
                ingredients.append(ingredient)
            }
        }
        
        print("📋 Parsed \(ingredients.count) ingredients")
        return ingredients
    }
    
    private func parseIngredientLine(_ line: String) -> IngredientData {
        // Remove bullet points and trim
        var cleaned = line.replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
        
        // Clean up complex fractions and approximations
        cleaned = cleaned.replacingOccurrences(of: #"\d+/\d+\s+[a-zA-Z]+\s+\([^)]*approx\.\s*([^)]+)\)"#, with: "$1", options: .regularExpression)
        
        // Try to extract amount, unit, and name
        do {
            // Enhanced pattern to handle more complex ingredient formats
            let regex = try NSRegularExpression(pattern: #"^([\d\/\.\-\s]+)?\s*([a-zA-Z]+)?\s+([^,(]+)(?:\s*[\(,].*?)?"#)
            if let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned)) {
                
                var amount = extractRange(match, at: 1, from: cleaned)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "1"
                let unit = extractRange(match, at: 2, from: cleaned)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = extractRange(match, at: 3, from: cleaned)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cleaned
                
                // Simplify complex fractions
                amount = simplifyFraction(amount)
                
                // Extract notes from parentheses or after comma
                var notes: String?
                if let noteMatch = cleaned.range(of: #"\([^)]+\)|,\s*.+"#, options: .regularExpression) {
                    notes = String(cleaned[noteMatch]).replacingOccurrences(of: "[(),]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                return IngredientData(name: name, amount: amount, unit: unit, notes: notes)
            }
        } catch {}
        
        // Fallback: treat entire line as ingredient name
        return IngredientData(name: cleaned, amount: "1", unit: nil, notes: nil)
    }
    
    private func simplifyFraction(_ amount: String) -> String {
        // Convert complex fractions to simple ones
        let simplifications: [String: String] = [
            "3/6": "1/2",
            "6/6": "1",
            "15/6": "2.5",
            "9/6": "1.5",
            "12/6": "2"
        ]
        
        for (complex, simple) in simplifications {
            if amount.contains(complex) {
                return amount.replacingOccurrences(of: complex, with: simple)
            }
        }
        
        return amount
    }
    
    private func parseSteps(from content: String) -> [StepData] {
        print("🍳 Parsing cooking steps from natural language")
        
        var steps: [StepData] = []
        
        // First try to parse numbered steps (1. 2. 3. etc.)
        steps = parseNumberedSteps(from: content)
        
        // If no numbered steps found, try parsing by lines starting with numbers
        if steps.isEmpty {
            steps = parseLineNumberedSteps(from: content)
        }
        
        // Fallback: split by paragraphs
        if steps.isEmpty {
            let paragraphs = content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for (index, paragraph) in paragraphs.enumerated() {
                let step = parseStepParagraph(paragraph, stepNumber: index + 1)
                steps.append(step)
            }
        }
        
        // Final fallback: split by sentences
        if steps.isEmpty {
            let sentences = content.components(separatedBy: ". ").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for (index, sentence) in sentences.enumerated() {
                let step = parseStepParagraph(sentence, stepNumber: index + 1)
                steps.append(step)
            }
        }
        
        print("📋 Parsed \(steps.count) cooking steps")
        return steps
    }
    
    private func parseNumberedSteps(from content: String) -> [StepData] {
        // Parse steps like "1. Mix ingredients" or "Step 1: Mix ingredients"
        do {
            let regex = try NSRegularExpression(pattern: #"(?:^|\n)(\d+)\.?\s+(.+?)(?=\n\d+\.|\n\n|\Z)"#, options: [.dotMatchesLineSeparators])
            let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            
            var steps: [StepData] = []
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: content),
                   let textRange = Range(match.range(at: 2), in: content),
                   let stepNumber = Int(content[numberRange]) {
                    
                    let stepText = String(content[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let step = parseStepParagraph(stepText, stepNumber: stepNumber)
                    steps.append(step)
                }
            }
            
            if !steps.isEmpty {
                print("✅ Found \(steps.count) numbered steps using regex pattern")
                return steps
            }
        } catch {
            print("⚠️ Regex parsing failed: \(error)")
        }
        
        return []
    }
    
    private func parseLineNumberedSteps(from content: String) -> [StepData] {
        // Parse steps that are on separate lines starting with numbers
        let lines = content.components(separatedBy: .newlines)
        var steps: [StepData] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if line starts with a number followed by period and space
            do {
                let regex = try NSRegularExpression(pattern: #"^(\d+)\.\s*(.+)"#)
                if let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
                   let numberRange = Range(match.range(at: 1), in: trimmed),
                   let textRange = Range(match.range(at: 2), in: trimmed),
                   let stepNumber = Int(trimmed[numberRange]) {
                    
                    let stepText = String(trimmed[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let step = parseStepParagraph(stepText, stepNumber: stepNumber)
                    steps.append(step)
                }
            } catch {
                print("⚠️ Line parsing regex failed: \(error)")
            }
        }
        
        if !steps.isEmpty {
            print("✅ Found \(steps.count) numbered steps using line parsing")
        }
        
        return steps
    }
    
    private func parseStepParagraph(_ paragraph: String, stepNumber: Int) -> StepData {
        let instruction = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract timing if present
        let estimatedTime = extractTimeFromText(instruction)
        
        // Extract temperature/heat info
        let temperature = extractTemperatureFromText(instruction)
        
        // Extract technique
        let technique = extractTechniqueFromText(instruction)
        
        return StepData(
            stepNumber: stepNumber,
            instruction: instruction,
            detailedExplanation: instruction, // Same as instruction for now
            estimatedTime: estimatedTime,
            temperature: temperature,
            technique: technique
        )
    }
    
    private func extractTimeFromText(_ text: String) -> Int? {
        do {
            let regex = try NSRegularExpression(pattern: #"(\d+)[-\s]*(\d+)?\s*(minute|min|second|sec)"#, options: .caseInsensitive)
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let numberRange = Range(match.range(at: 1), in: text),
               let number = Int(text[numberRange]) {
                
                let unitRange = Range(match.range(at: 3), in: text)
                let unit = unitRange.map { text[$0].lowercased() } ?? "minute"
                
                if unit.contains("second") || unit.contains("sec") {
                    return number
                } else {
                    return number * 60 // Convert minutes to seconds
                }
            }
        } catch {}
        
        return nil
    }
    
    private func extractTemperatureFromText(_ text: String) -> String? {
        let heatLevels = ["low", "medium", "high", "gentle", "vigorous"]
        let lowercased = text.lowercased()
        
        for level in heatLevels {
            if lowercased.contains(level) {
                return level + " heat"
            }
        }
        
        return nil
    }
    
    private func extractTechniqueFromText(_ text: String) -> String? {
        let techniques = ["sauté", "sautéing", "fry", "frying", "boil", "boiling", "simmer", "simmering", "roast", "roasting", "bake", "baking", "steam", "steaming", "grill", "grilling"]
        let lowercased = text.lowercased()
        
        for technique in techniques {
            if lowercased.contains(technique) {
                return technique
            }
        }
        
        return nil
    }
    
    private func extractRange(_ match: NSTextCheckingResult, at index: Int, from string: String) -> String? {
        guard match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: string) else {
            return nil
        }
        return String(string[range])
    }
    
    private func extractScalingNotes(from content: String) -> String? {
        // Look for scaling intelligence section
        do {
            let regex = try NSRegularExpression(pattern: #"SCALING INTELLIGENCE:(.*?)(?=\n\n|\Z)"#, options: [.dotMatchesLineSeparators])
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        
        return nil
    }
    
    private func extractOriginalServings(from content: String) -> Int? {
        // Look for original serving size mentioned in scaling notes
        do {
            let regex = try NSRegularExpression(pattern: #"Original recipe.*?serves?:?\s*(\d+)"#, options: .caseInsensitive)
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
               let numberRange = Range(match.range(at: 1), in: content),
               let servings = Int(content[numberRange]) {
                return servings
            }
        } catch {}
        
        return nil
    }
}

enum RecipeError: LocalizedError {
    case invalidURL
    case networkError(String)
    case analysisFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid YouTube URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .analysisFailure(let message):
            return "Failed to analyze video: \(message)"
        }
    }
}

private struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
    }
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
}

private struct RecipeData: Codable {
    let title: String
    let description: String?
    let cuisine: String?
    let difficulty: String
    let totalTime: Int
    let servings: Int
    let ingredients: [IngredientData]
    let steps: [StepData]
    let chefsWisdom: String?
    let scalingNotes: String?
    let originalServings: Int?
}

private struct IngredientData: Codable {
    let name: String
    let amount: String
    let unit: String?
    let notes: String?
}

private struct StepData: Codable {
    let stepNumber: Int
    let instruction: String
    let detailedExplanation: String?
    let estimatedTime: Int?
    let temperature: String?
    let technique: String?
}
