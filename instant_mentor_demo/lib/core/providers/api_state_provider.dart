import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for API operations
class ApiState<T> {
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final T? data;
  final DateTime? lastUpdate;

  const ApiState({
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage = '',
    this.data,
    this.lastUpdate,
  });

  ApiState<T> copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    T? data,
    DateTime? lastUpdate,
  }) {
    return ApiState<T>(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      data: data ?? this.data,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Factory constructors for common states
  factory ApiState.loading() => const ApiState(isLoading: true);

  factory ApiState.success(T data) => ApiState(
        data: data,
        lastUpdate: DateTime.now(),
      );

  factory ApiState.error(String message) => ApiState(
        hasError: true,
        errorMessage: message,
      );
}

/// Generic API state notifier
class ApiStateNotifier<T> extends StateNotifier<ApiState<T>> {
  ApiStateNotifier() : super(const ApiState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setData(T data) {
    state = ApiState.success(data);
  }

  void setError(String error) {
    state = ApiState.error(error);
  }

  void reset() {
    state = const ApiState();
  }

  /// Execute async operation with automatic state management
  Future<void> execute(Future<T> Function() operation) async {
    state = ApiState.loading();
    try {
      final result = await operation();
      state = ApiState.success(result);
    } catch (error) {
      state = ApiState.error(error.toString());
    }
  }
}

/// Provider for generic API operations
final apiStateProvider = StateNotifierProvider.autoDispose
    .family<ApiStateNotifier<dynamic>, ApiState<dynamic>, String>((ref, key) {
  return ApiStateNotifier<dynamic>();
});

/// Specific providers for common API operations
final loginApiProvider = StateNotifierProvider.autoDispose<
    ApiStateNotifier<Map<String, dynamic>>,
    ApiState<Map<String, dynamic>>>((ref) {
  return ApiStateNotifier<Map<String, dynamic>>();
});

final signupApiProvider = StateNotifierProvider.autoDispose<
    ApiStateNotifier<Map<String, dynamic>>,
    ApiState<Map<String, dynamic>>>((ref) {
  return ApiStateNotifier<Map<String, dynamic>>();
});

final helpRequestApiProvider = StateNotifierProvider.autoDispose<
    ApiStateNotifier<Map<String, dynamic>>,
    ApiState<Map<String, dynamic>>>((ref) {
  return ApiStateNotifier<Map<String, dynamic>>();
});

final chatMessageApiProvider = StateNotifierProvider.autoDispose.family<
    ApiStateNotifier<Map<String, dynamic>>,
    ApiState<Map<String, dynamic>>,
    String>((ref, chatId) {
  return ApiStateNotifier<Map<String, dynamic>>();
});

/// Simple loading state providers
final isLoadingProvider =
    StateProvider.autoDispose.family<bool, String>((ref, key) => false);
final isSubmittingProvider =
    StateProvider.autoDispose.family<bool, String>((ref, key) => false);
final isSendingProvider =
    StateProvider.autoDispose.family<bool, String>((ref, key) => false);
