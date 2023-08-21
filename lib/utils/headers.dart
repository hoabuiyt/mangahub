import 'dart:convert';

import 'package:mangahub/main.dart';
import 'package:mangahub/models/settings.dart';
import 'package:mangahub/services/http_service/cloudflare/providers/cookie_providers.dart';
import 'package:mangahub/sources/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'headers.g.dart';

@riverpod
Map<String, String> headers(HeadersRef ref,
    {required String source, required String lang}) {
  final sourceM = getSource(lang, source);
  if (sourceM.headers!.isEmpty && !sourceM.hasCloudflare!) {
    return {};
  }
  Map<String, String> newHeaders = {};
  if (sourceM.headers!.isNotEmpty) {
    final headers = jsonDecode(sourceM.headers!) as Map;
    newHeaders =
        headers.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  if (sourceM.hasCloudflare!) {
    final userAgent = isar.settings.getSync(227)!.userAgent!;
    final cookie = ref.watch(cookieStateProvider(source));

    newHeaders.addAll({'User-Agent': userAgent, "Cookie": cookie});
  }
  return newHeaders;
}
