import 'package:isar/isar.dart';
import 'package:mangahub/main.dart';
import 'package:mangahub/models/chapter.dart';
import 'package:mangahub/models/history.dart';
import 'package:mangahub/models/manga.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

@riverpod
Stream<List<History>> getAllHistoryStream(GetAllHistoryStreamRef ref,
    {required bool isManga}) async* {
  yield* isar.historys
      .filter()
      .idIsNotNull()
      .and()
      .chapter((q) => q.manga((q) => q.isMangaEqualTo(isManga)))
      .watch(fireImmediately: true);
}
