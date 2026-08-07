import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _mainCategories = [];
  bool _isLoading = false;
  String? _error;

  // Convenience getter for empty list of main categories
  List<Category> get mainCategories => _mainCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all main categories from API
  Future<void> loadMainCategories() async {
    print('📂 Loading main categories...');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.getCategories();

      if (result.statusCode == 200 && result.data != null) {
        final data = result.data as Map<String, dynamic>;
        
        if (data['success'] == true) {
          final categoriesList = (data['categories'] as List? ?? [])
              .map((cat) => Category.fromJson(cat as Map<String, dynamic>))
              .toList();
          
          // Sort by sort_order
          categoriesList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          
          _mainCategories = categoriesList;
          print('✅ Loaded ${_mainCategories.length} main categories');
          
          // Add "All" category at the beginning if not present
          if (_mainCategories.isNotEmpty) {
            _mainCategories.insert(
              0,
              const Category(
                id: 0,
                name: 'All',
                slug: 'all',
                sortOrder: -1,
              ),
            );
          }
        } else {
          _error = data['error'] as String? ?? 'Failed to load categories';
          print('❌ Error: $_error');
        }
      } else {
        _error = 'Failed to fetch categories (Status: ${result.statusCode})';
        print('❌ Error: $_error');
      }
    } catch (e) {
      _error = 'Error loading categories: $e';
      print('❌ Exception: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a category by slug
  Category? getCategoryBySlug(String slug) {
    try {
      return _mainCategories.firstWhere((cat) => cat.slug == slug);
    } catch (e) {
      return null;
    }
  }

  /// Get a category by ID
  Category? getCategoryById(int id) {
    try {
      return _mainCategories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get category display names for dropdown/filter UI
  List<String> getCategoryDisplayNames() {
    return _mainCategories.map((cat) => cat.name).toList();
  }

  /// Get category slugs for API filtering
  List<String> getCategorySlugs() {
    return _mainCategories.map((cat) => cat.slug).toList();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh categories from API
  Future<void> refresh() async {
    _mainCategories.clear();
    _error = null;
    notifyListeners();
    await loadMainCategories();
  }
}

// Singleton instance
final categoryProvider = CategoryProvider();
