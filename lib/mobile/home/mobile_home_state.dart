import '../../models/content_item.dart';

class MobileHomeState {
  final List<ContentItem> banners;
  final List<ContentItem> items;
  final List<String> categories;
  final List<String> platformLabels;
  final int selectedPlatformIndex;
  final int selectedCategoryIndex;
  final bool loading;
  final String errorMessage;

  const MobileHomeState({
    required this.banners,
    required this.items,
    required this.categories,
    required this.platformLabels,
    required this.selectedPlatformIndex,
    required this.selectedCategoryIndex,
    this.loading = false,
    this.errorMessage = '',
  });

  factory MobileHomeState.initial() => const MobileHomeState(
        banners: [],
        items: [],
        categories: [],
        platformLabels: [],
        selectedPlatformIndex: 0,
        selectedCategoryIndex: 0,
        loading: true,
        errorMessage: '',
      );

  MobileHomeState copyWith({
    List<ContentItem>? banners,
    List<ContentItem>? items,
    List<String>? categories,
    List<String>? platformLabels,
    int? selectedPlatformIndex,
    int? selectedCategoryIndex,
    bool? loading,
    String? errorMessage,
  }) {
    return MobileHomeState(
      banners: banners ?? this.banners,
      items: items ?? this.items,
      categories: categories ?? this.categories,
      platformLabels: platformLabels ?? this.platformLabels,
      selectedPlatformIndex: selectedPlatformIndex ?? this.selectedPlatformIndex,
      selectedCategoryIndex: selectedCategoryIndex ?? this.selectedCategoryIndex,
      loading: loading ?? this.loading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
