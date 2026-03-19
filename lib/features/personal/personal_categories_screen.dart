import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/personal_models.dart';
import '../../core/repositories/providers.dart';

class PersonalCategoriesScreen extends ConsumerWidget {
  const PersonalCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(personalCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('קטגוריות הוצאה'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text('עדיין אין קטגוריות.\nלחץ על + כדי להוסיף.'),
            );
          }

          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                onTap: () =>
                    _openAddCategoryDialog(context, ref, existing: category),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: category.isDefault
                      ? null
                      : () async {
                          final auth =
                              ref.read(firebaseAuthProvider).currentUser;
                          if (auth == null) return;
                          final repo = ref.read(personalRepositoryProvider);
                          await repo.deleteCategory(auth.uid, category.id);
                          ref.invalidate(personalCategoriesProvider);
                        },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('שגיאה בטעינת קטגוריות: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openAddCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    PersonalCategory? existing,
  }) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'קטגוריה חדשה' : 'עריכת קטגוריה'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'שם הקטגוריה',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'ביטול',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                final user = ref.read(firebaseAuthProvider).currentUser;
                if (user == null) return;

                final repo = ref.read(personalRepositoryProvider);
                final newCategory = PersonalCategory(
                  id: existing?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  isDefault: existing?.isDefault ?? false,
                  colorValue: existing?.colorValue,
                );
                await repo.upsertCategory(user.uid, newCategory);
                ref.invalidate(personalCategoriesProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('שמור'),
            ),
          ],
        );
      },
    );
  }
}

