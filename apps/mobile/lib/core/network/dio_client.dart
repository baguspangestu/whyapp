import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../constants/storage_constants.dart';

class DioClient {
  DioClient(SharedPreferences prefs)
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          final token = prefs.getString(StorageConstants.accessToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isUnauthorized = error.response?.statusCode == 401;
          final isAuthRequest = request.path.startsWith('auth/');
          final alreadyRetried = request.extra['retried'] == true;
          final refreshToken = prefs.getString(StorageConstants.refreshToken);

          if (!isUnauthorized ||
              isAuthRequest ||
              alreadyRetried ||
              refreshToken == null ||
              refreshToken.isEmpty) {
            handler.next(error);
            return;
          }

          try {
            final refreshClient = Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ));
            final response = await refreshClient.post<Map<String, dynamic>>(
              ApiConstants.refresh,
              data: {'refreshToken': refreshToken},
            );
            final accessToken = response.data!['accessToken'] as String;
            final nextRefreshToken =
                response.data!['refreshToken'] as String? ?? refreshToken;
            await prefs.setString(
              StorageConstants.accessToken,
              accessToken,
            );
            await prefs.setString(
              StorageConstants.refreshToken,
              nextRefreshToken,
            );

            request.extra['retried'] = true;
            request.headers['Authorization'] = 'Bearer $accessToken';
            handler.resolve(await dio.fetch<dynamic>(request));
          } catch (_) {
            await prefs.remove(StorageConstants.user);
            await prefs.remove(StorageConstants.accessToken);
            await prefs.remove(StorageConstants.refreshToken);
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio dio;
}
