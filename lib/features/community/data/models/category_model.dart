import '../../domain/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({required super.name});

  factory CategoryModel.fromJson(String name) {
    return CategoryModel(name: name);
  }
}

class CategoriesResponseModel {
  const CategoriesResponseModel({required this.categories});

  final List<String> categories;

  factory CategoriesResponseModel.fromJson(Map<String, dynamic> json) {
    final categoriesList = json['categories'] as List<dynamic>;
    return CategoriesResponseModel(
      categories: categoriesList.map((c) => c as String).toList(),
    );
  }
}