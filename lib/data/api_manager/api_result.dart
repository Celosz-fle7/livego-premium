class ApiResult<T> {
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final bool fromFallback;
  final bool success;

  const ApiResult.success(this.data, {this.fromFallback = false})
      : error = null,
        stackTrace = null,
        success = true;

  const ApiResult.failure(this.error, {this.stackTrace})
      : data = null,
        fromFallback = false,
        success = false;
}
