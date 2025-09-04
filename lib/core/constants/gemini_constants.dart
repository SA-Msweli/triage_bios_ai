class GeminiConstants {
  // Gemini AI Configuration
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com';
  static const String geminiApiVersion = 'v1beta';

  // Model Configuration
  static const String geminiModelId = 'gemini-1.5-flash';
  static const String triageModelVersion = 'v1.0.0';

  // API Endpoints
  static const String generateEndpoint =
      '/v1beta/models/gemini-1.5-flash:generateContent';

  // Request Configuration
  static const int maxTokens = 500;
  static const double temperature =
      0.3; // Lower for more consistent medical responses
  static const int topK = 40;
  static const double topP = 0.9;
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 10);

  // Safety Settings
  static const List<Map<String, dynamic>> safetySettings = [
    {
      'category': 'HARM_CATEGORY_HARASSMENT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
  ];

  // Triage Prompts
  static const String systemPrompt = '''
You are a medical AI assistant specialized in emergency triage. Your role is to assess patient symptoms and provide a severity score from 0-10 where:

0-2: Non-urgent (can wait hours or days)
3-4: Standard (should be seen within 2-4 hours)
5-6: Urgent (should be seen within 1 hour)
7-8: High priority (should be seen within 30 minutes)
9-10: Critical/Life-threatening (immediate attention required)

Consider the following factors:
- Symptom severity and duration
- Vital signs if provided
- Age-related risk factors
- Potential for rapid deterioration

Always provide:
1. A severity score (0-10)
2. Brief explanation of reasoning
3. Key concerning symptoms
4. Recommended timeframe for care

Be conservative - when in doubt, err on the side of higher severity.
''';

  static const String triagePromptTemplate =
      '''
$systemPrompt

Patient presents with the following symptoms:
{symptoms}

Additional vital signs data:
{vitals}

Patient demographics:
{demographics}

Please provide a triage assessment in the following JSON format:
{
  "severity_score": <number 0-10>,
  "confidence_lower": <number>,
  "confidence_upper": <number>,
  "explanation": "<brief explanation>",
  "key_symptoms": ["<symptom1>", "<symptom2>"],
  "concerning_findings": ["<finding1>", "<finding2>"],
  "recommended_actions": ["<action1>", "<action2>"],
  "urgency_level": "<critical|urgent|standard|non_urgent>",
  "time_to_treatment": "<timeframe>"
}
''';
}
