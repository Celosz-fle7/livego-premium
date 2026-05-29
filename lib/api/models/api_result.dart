class ApiResult<T> {
  final T? data;
  final Object? error;
  final bool success;

  const ApiResult.success(this.data)
      : success = true,
        error = null;

  const ApiResult.failure(this.error)
      : success = false,
        data = null;
}
