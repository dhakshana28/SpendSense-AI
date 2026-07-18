import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
	final http.Client _client;

	ApiService([http.Client? client]) : _client = client ?? http.Client();

	Future<Map<String, dynamic>> postJson(
		Uri uri,
		Map<String, dynamic> body, {
		Map<String, String>? headers,
	}) async {
		final response = await _client.post(
			uri,
			headers: {
				'Content-Type': 'application/json',
				...?headers,
			},
			body: jsonEncode(body),
		);

		if (response.statusCode >= 200 && response.statusCode < 300) {
			return jsonDecode(response.body) as Map<String, dynamic>;
		}

		throw Exception('API request failed: ${response.statusCode} ${response.body}');
	}
}
