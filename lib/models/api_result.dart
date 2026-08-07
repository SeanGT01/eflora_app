/// Generic API Result wrapper for consistent error handling
sealed class ApiResult<T> {
  const ApiResult();

  /// Successful result with data
  factory ApiResult.success(T data) = _Success<T>;

  /// Error result with message and status code
  factory ApiResult.error(String message, int statusCode) = _Error<T>;

  /// Map the result to a new type
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int statusCode) error,
  }) {
    return switch (this) {
      _Success(data: final data) => success(data),
      _Error(message: final message, statusCode: final statusCode) =>
        error(message, statusCode),
    };
  }

  /// Get data or null if error
  T? getOrNull() {
    return when(
      success: (data) => data,
      error: (_, __) => null,
    );
  }

  /// Check if result is successful
  bool isSuccess() => this is _Success<T>;

  /// Check if result is error
  bool isError() => this is _Error<T>;
}

final class _Success<T> extends ApiResult<T> {
  final T data;
  const _Success(this.data);
}

final class _Error<T> extends ApiResult<T> {
  final String message;
  final int statusCode;
  const _Error(this.message, this.statusCode);
}
