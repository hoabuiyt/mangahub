import 'package:isar/isar.dart';
import 'package:mangahub/main.dart';
import 'package:mangahub/models/source.dart';

Source getSource(String lang, String name) {
  final sourcesList = isar.sources.filter().idIsNotNull().findAllSync();
  return sourcesList.firstWhere(
    (element) =>
        element.name!.toLowerCase() == name.toLowerCase() &&
        element.lang == lang,
    orElse: () => throw (),
  );
}
