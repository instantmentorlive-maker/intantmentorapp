import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for UI form controls
class UIState {
  final bool isAvailable;
  final String selectedSubject;
  final String selectedUrgency;
  final int currentStep;
  final int currentIndex;
  final Map<String, dynamic> formData;

  const UIState({
    this.isAvailable = false,
    this.selectedSubject = '',
    this.selectedUrgency = 'medium',
    this.currentStep = 0,
    this.currentIndex = 0,
    this.formData = const {},
  });

  UIState copyWith({
    bool? isAvailable,
    String? selectedSubject,
    String? selectedUrgency,
    int? currentStep,
    int? currentIndex,
    Map<String, dynamic>? formData,
  }) {
    return UIState(
      isAvailable: isAvailable ?? this.isAvailable,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedUrgency: selectedUrgency ?? this.selectedUrgency,
      currentStep: currentStep ?? this.currentStep,
      currentIndex: currentIndex ?? this.currentIndex,
      formData: formData ?? this.formData,
    );
  }
}

/// Generic UI state notifier
class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(const UIState());

  void setAvailability(bool available) {
    state = state.copyWith(isAvailable: available);
  }

  void setSelectedSubject(String subject) {
    state = state.copyWith(selectedSubject: subject);
  }

  void setSelectedUrgency(String urgency) {
    state = state.copyWith(selectedUrgency: urgency);
  }

  void setCurrentStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void setCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void updateFormData(String key, dynamic value) {
    final newFormData = Map<String, dynamic>.from(state.formData);
    newFormData[key] = value;
    state = state.copyWith(formData: newFormData);
  }

  void resetForm() {
    state = state.copyWith(
      formData: {},
      selectedSubject: '',
      selectedUrgency: 'medium',
      currentStep: 0,
    );
  }
}

/// Provider for global UI state - using autoDispose
final uiStateProvider =
    StateNotifierProvider.autoDispose<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
});

/// Family provider for feature-specific UI states
final featureUIStateProvider = StateNotifierProvider.autoDispose
    .family<UIStateNotifier, UIState, String>((ref, featureKey) {
  return UIStateNotifier();
});

/// Simple boolean state providers for toggles
final availabilityProvider = StateProvider.autoDispose<bool>((ref) => false);
final mentorAvailabilityProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// Simple string state providers for selections
final selectedSubjectProvider = StateProvider.autoDispose<String>((ref) => '');
final selectedUrgencyProvider =
    StateProvider.autoDispose<String>((ref) => 'medium');

/// Simple int state providers for navigation
final currentStepProvider = StateProvider.autoDispose<int>((ref) => 0);
final currentIndexProvider = StateProvider.autoDispose<int>((ref) => 0);
