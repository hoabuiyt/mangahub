import 'package:isar/isar.dart';
import 'package:mangahub/main.dart';
import 'package:mangahub/models/chapter.dart';
import 'package:mangahub/models/manga.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

@riverpod
Stream<Manga?> getMangaDetailStream(GetMangaDetailStreamRef ref,
    {required int mangaId}) async* {
  yield* isar.mangas.watchObject(mangaId, fireImmediately: true);
}

@riverpod
Stream<List<Chapter>> getChaptersStream(
  GetChaptersStreamRef ref, {
  required int mangaId,
}) async* {
  yield* isar.chapters
      .filter()
      .manga((q) => q.idEqualTo(mangaId))
      .watch(fireImmediately: true);
}
