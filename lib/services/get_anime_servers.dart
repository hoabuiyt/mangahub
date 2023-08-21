import 'dart:async';
import 'package:dart_eval/stdlib/core.dart';
import 'package:mangahub/eval/bridge_class/manga_model.dart';
import 'package:mangahub/eval/bridge_class/model.dart';
import 'package:mangahub/eval/compiler/compiler.dart';
import 'package:mangahub/models/chapter.dart';
import 'package:mangahub/models/video.dart';
import 'package:mangahub/eval/runtime/runtime.dart';
import 'package:mangahub/sources/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_anime_servers.g.dart';

@riverpod
Future<List<Video>> getAnimeServers(
  GetAnimeServersRef ref, {
  required Chapter chapter,
}) async {
  List<Video> video = [];
  if (!chapter.manga.value!.isLocalArchive!) {
    final source =
        getSource(chapter.manga.value!.lang!, chapter.manga.value!.source!);

    final bytecode = compilerEval(source.sourceCode!);

    final runtime = runtimeEval(bytecode);
    runtime.args = [
      $MangaModel.wrap(MangaModel(
        lang: source.lang,
        link: chapter.url,
        baseUrl: source.baseUrl,
        source: source.name,
        apiUrl: source.apiUrl,
        sourceId: source.id,
      ))
    ];
    var res = await runtime.executeLib(
        'package:mangahub/source_code.dart', 'getVideoList');
    if (res is $List) {
      video = res.$reified
          .map(
            (e) => Video(e.url, e.quality, e.originalUrl, headers: e.headers),
          )
          .toList();
    }
  }
  return video;
}
