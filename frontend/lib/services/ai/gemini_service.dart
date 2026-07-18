
import '../../app/constants/app_constants.dart';
import '../api/api_service.dart';

class GeminiService {
	final ApiService _apiService;

	GeminiService([ApiService? apiService]) : _apiService = apiService ?? ApiService();

	Future<String> analyzeExpenses(String expenseSummary) async {
		final prompt = 'Analyze the following expenses and provide personalized recommendations:\n\n$expenseSummary';
		return _sendAiRequest(prompt);
	}

	Future<String> budgetSuggestions(String budgetSummary) async {
		final prompt = 'Review the budget details and suggest improvements in clear, simple language:\n\n$budgetSummary';
		return _sendAiRequest(prompt);
	}

	Future<String> savingSuggestions(String financialSummary) async {
		final prompt = 'Provide saving suggestions based on the following financial summary:\n\n$financialSummary';
		return _sendAiRequest(prompt);
	}

	Future<String> financialAdvice(String context) async {
		final prompt = 'Offer friendly financial advice for this user context:\n\n$context';
		return _sendAiRequest(prompt);
	}

	Future<String> monthlySummary(String transactionSummary) async {
		final prompt = 'Summarize the monthly performance and recommend next steps:\n\n$transactionSummary';
		return _sendAiRequest(prompt);
	}

	Future<String> chatAssistant(String userMessage) async {
		final prompt = 'You are a smart finance assistant. Respond clearly and helpfully. User: $userMessage';
		return _sendAiRequest(prompt);
	}

	Future<String> _sendAiRequest(String prompt) async {
		if (AppConstants.geminiApiKey.isEmpty) {
			return 'Gemini API key is missing. Enter your API key in AppConstants.geminiApiKey to enable AI insights.';
		}

		final uri = Uri.parse(
			'https://generativelanguage.googleapis.com/v1beta2/models/${AppConstants.geminiModel}:generate',
		);

		final headers = {
			'Authorization': 'Bearer ${AppConstants.geminiApiKey}',
			'Content-Type': 'application/json',
		};

		final body = {
			'prompt': {
				'text': prompt,
			},
			'temperature': 0.7,
			'maxOutputTokens': 256,
		};

		final response = await _apiService.postJson(uri, body, headers: headers);
		final candidates = response['candidates'] as List<dynamic>?;
		if (candidates != null && candidates.isNotEmpty) {
			final first = candidates.first as Map<String, dynamic>;
			final output = first['output'] as String? ?? first['text'] as String?;
			return output ?? 'No AI response produced.';
		}

		return 'AI returned an empty response.';
	}
}
