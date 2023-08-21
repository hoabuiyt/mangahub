import 'package:isar/isar.dart';
import 'package:mangahub/main.dart';
import 'package:mangahub/models/category.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

@riverpod
Stream<List<Category>> getMangaCategorieStream(GetMangaCategorieStreamRef ref,
    {required bool isManga}) async* {
  yield* isar.categorys
      .filter()
      .idIsNotNull()
      .and()
      .forMangaEqualTo(isManga)
      .watch(fireImmediately: true);
}
