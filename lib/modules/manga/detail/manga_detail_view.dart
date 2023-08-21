import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:draggable_menu/draggable_menu.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:mangahub/main.dart';
import 'package:mangahub/models/chapter.dart';
import 'package:mangahub/models/download.dart';
import 'package:mangahub/models/manga.dart';
import 'package:mangahub/models/settings.dart';
import 'package:mangahub/models/track.dart';
import 'package:mangahub/models/track_preference.dart';
import 'package:mangahub/models/track_search.dart';
import 'package:mangahub/modules/library/providers/local_archive.dart';
import 'package:mangahub/modules/manga/detail/providers/track_state_providers.dart';
import 'package:mangahub/modules/manga/detail/widgets/tracker_search_widget.dart';
import 'package:mangahub/modules/manga/detail/widgets/tracker_widget.dart';
import 'package:mangahub/modules/more/settings/track/widgets/track_listile.dart';
import 'package:mangahub/providers/l10n_providers.dart';
import 'package:mangahub/sources/utils/utils.dart';
import 'package:mangahub/utils/cached_network.dart';
import 'package:mangahub/utils/colors.dart';
import 'package:mangahub/utils/headers.dart';
import 'package:mangahub/utils/media_query.dart';
import 'package:mangahub/utils/utils.dart';
import 'package:mangahub/modules/manga/detail/providers/isar_providers.dart';
import 'package:mangahub/modules/manga/detail/providers/state_providers.dart';
import 'package:mangahub/modules/manga/detail/widgets/readmore.dart';
import 'package:mangahub/modules/manga/detail/widgets/chapter_filter_list_tile_widget.dart';
import 'package:mangahub/modules/manga/detail/widgets/chapter_list_tile_widget.dart';
import 'package:mangahub/modules/manga/detail/widgets/chapter_sort_list_tile_widget.dart';
import 'package:mangahub/modules/manga/download/providers/download_provider.dart';
import 'package:mangahub/modules/widgets/error_text.dart';
import 'package:mangahub/modules/widgets/progress_center.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

class MangaDetailView extends ConsumerStatefulWidget {
  final Function(bool) isExtended;

  final Widget? titleDescription;
  final List<Color>? backButtonColors;
  final Widget? action;
  final Manga? manga;
  final bool sourceExist;
  const MangaDetailView({
    super.key,
    required this.isExtended,
    this.titleDescription,
    this.backButtonColors,
    this.action,
    required this.sourceExist,
    required this.manga,
  });

  @override
  ConsumerState<MangaDetailView> createState() => _MangaDetailViewState();
}

class _MangaDetailViewState extends ConsumerState<MangaDetailView>
    with TickerProviderStateMixin {
  @override
  void initState() {
    _scrollController = ScrollController()
      ..addListener(() {
        ref.read(offetProvider.notifier).state = _scrollController.offset;
      });
    super.initState();
  }

  final offetProvider = StateProvider((ref) => 0.0);
  bool _expanded = false;
  ScrollController _scrollController = ScrollController();
  late final isLocalArchive = widget.manga!.isLocalArchive ?? false;
  @override
  Widget build(BuildContext context) {
    final isLongPressed = ref.watch(isLongPressedStateProvider);
    final chapterNameList = ref.watch(chaptersListStateProvider);
    final scanlators = ref.watch(scanlatorsFilterStateProvider(widget.manga!));
    bool reverse = ref
        .watch(sortChapterStateProvider(mangaId: widget.manga!.id!))
        .reverse!;
    final filterUnread =
        ref.watch(chapterFilterUnreadStateProvider(mangaId: widget.manga!.id!));
    final filterBookmarked = ref.watch(
        chapterFilterBookmarkedStateProvider(mangaId: widget.manga!.id!));
    final filterDownloaded = ref.watch(
        chapterFilterDownloadedStateProvider(mangaId: widget.manga!.id!));
    final sortChapter = ref
        .watch(sortChapterStateProvider(mangaId: widget.manga!.id!))
        .index as int;
    final chapters =
        ref.watch(getChaptersStreamProvider(mangaId: widget.manga!.id!));
    return NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.forward) {
            widget.isExtended(true);
          }
          if (notification.direction == ScrollDirection.reverse) {
            widget.isExtended(false);
          }
          return true;
        },
        child: chapters.when(
          data: (data) {
            List<Chapter> chapters = _filterAndSortChapter(
                data: data,
                filterUnread: filterUnread,
                filterBookmarked: filterBookmarked,
                filterDownloaded: filterDownloaded,
                sortChapter: sortChapter,
                filterScanlator: scanlators.$2);
            ref.read(chaptersListttStateProvider.notifier).set(chapters);
            return _buildWidget(
                chapters: chapters,
                reverse: reverse,
                chapterList: chapterNameList,
                isLongPressed: isLongPressed);
          },
          error: (Object error, StackTrace stackTrace) {
            return ErrorText(error);
          },
          loading: () {
            return _buildWidget(
                chapters: widget.manga!.chapters.toList(),
                reverse: reverse,
                chapterList: chapterNameList,
                isLongPressed: isLongPressed);
          },
        ));
  }

  List<Chapter> _filterAndSortChapter(
      {required List<Chapter> data,
      required int filterUnread,
      required int filterBookmarked,
      required int filterDownloaded,
      required int sortChapter,
      required List<String> filterScanlator}) {
    List<Chapter>? chapterList;
    chapterList = data
        .where((element) => filterUnread == 1
            ? element.isRead == false
            : filterUnread == 2
                ? element.isRead == true
                : true)
        .where((element) => filterBookmarked == 1
            ? element.isBookmarked == true
            : filterBookmarked == 2
                ? element.isBookmarked == false
                : true)
        .where((element) {
          final modelChapDownload = isar.downloads
              .filter()
              .idIsNotNull()
              .chapterIdEqualTo(element.id)
              .findAllSync();
          return filterDownloaded == 1
              ? modelChapDownload.isNotEmpty &&
                  modelChapDownload.first.isDownload == true
              : filterDownloaded == 2
                  ? !(modelChapDownload.isNotEmpty &&
                      modelChapDownload.first.isDownload == true)
                  : true;
        })
        .where((element) => !filterScanlator.contains(element.scanlator))
        .toList();
    List<Chapter> chapters =
        sortChapter == 1 ? chapterList.reversed.toList() : chapterList;
    if (sortChapter == 0) {
      chapters.sort(
        (a, b) {
          return a.scanlator!.compareTo(b.scanlator!) |
              a.dateUpload!.compareTo(b.dateUpload!);
        },
      );
    } else if (sortChapter == 2) {
      chapters.sort(
        (a, b) {
          return a.dateUpload!.compareTo(b.dateUpload!);
        },
      );
    }
    return chapterList;
  }

  Widget _buildWidget(
      {required List<Chapter> chapters,
      required bool reverse,
      required List<Chapter> chapterList,
      required bool isLongPressed}) {
    return Stack(
      children: [
        Consumer(
          builder: (context, ref, child) {
            return Positioned(
              top: 0,
              child: ref.watch(offetProvider) == 0.0
                  ? Stack(
                      children: [
                        widget.manga!.customCoverImage != null
                            ? Image.memory(
                                widget.manga!.customCoverImage as Uint8List,
                                width: mediaWidth(context, 1),
                                height: 300,
                                fit: BoxFit.cover)
                            : cachedNetworkImage(
                                headers: ref.watch(headersProvider(
                                    source: widget.manga!.source!,
                                    lang: widget.manga!.lang!)),
                                imageUrl: widget.manga!.imageUrl!,
                                width: mediaWidth(context, 1),
                                height: 300,
                                fit: BoxFit.cover),
                        Stack(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: mediaWidth(context, 1),
                                  height: AppBar().preferredSize.height,
                                  color: isTablet(context)
                                      ? Theme.of(context)
                                          .scaffoldBackgroundColor
                                      : Theme.of(context)
                                          .scaffoldBackgroundColor
                                          .withOpacity(0.9),
                                ),
                                Container(
                                  width: mediaWidth(context, 1),
                                  height: 465,
                                  color: isTablet(context)
                                      ? Theme.of(context)
                                          .scaffoldBackgroundColor
                                      : Theme.of(context)
                                          .scaffoldBackgroundColor
                                          .withOpacity(0.9),
                                ),
                              ],
                            ),
                            Positioned(
                              bottom: 0,
                              child: Container(
                                  width: mediaWidth(context, 1),
                                  height: 100,
                                  color: Theme.of(context)
                                      .scaffoldBackgroundColor),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(),
            );
          },
        ),
        Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: PreferredSize(
                preferredSize: Size.fromHeight(AppBar().preferredSize.height),
                child: Consumer(
                  builder: (context, ref, child) {
                    final l10n = l10nLocalizations(context)!;
                    final isNotFiltering = ref.watch(
                        chapterFilterResultStateProvider(manga: widget.manga!));
                    final isLongPressed = ref.watch(isLongPressedStateProvider);
                    return isLongPressed
                        ? Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: AppBar(
                              title: Text(chapterList.length.toString()),
                              backgroundColor:
                                  primaryColor(context).withOpacity(0.2),
                              leading: IconButton(
                                  onPressed: () {
                                    ref
                                        .read(
                                            chaptersListStateProvider.notifier)
                                        .clear();

                                    ref
                                        .read(
                                            isLongPressedStateProvider.notifier)
                                        .update(!isLongPressed);
                                  },
                                  icon: const Icon(Icons.clear)),
                              actions: [
                                IconButton(
                                    onPressed: () {
                                      for (var chapter in chapters) {
                                        ref
                                            .read(chaptersListStateProvider
                                                .notifier)
                                            .selectAll(chapter);
                                      }
                                    },
                                    icon: const Icon(Icons.select_all)),
                                IconButton(
                                    onPressed: () {
                                      if (chapters.length ==
                                          chapterList.length) {
                                        for (var chapter in chapters) {
                                          ref
                                              .read(chaptersListStateProvider
                                                  .notifier)
                                              .selectSome(chapter);
                                        }
                                        ref
                                            .read(isLongPressedStateProvider
                                                .notifier)
                                            .update(false);
                                      } else {
                                        for (var chapter in chapters) {
                                          ref
                                              .read(chaptersListStateProvider
                                                  .notifier)
                                              .selectSome(chapter);
                                        }
                                      }
                                    },
                                    icon:
                                        const Icon(Icons.flip_to_back_rounded)),
                              ],
                            ),
                          )
                        : AppBar(
                            title: ref.watch(offetProvider) > 200
                                ? Text(
                                    widget.manga!.name!,
                                    style: const TextStyle(fontSize: 17),
                                  )
                                : null,
                            backgroundColor: ref.watch(offetProvider) == 0.0
                                ? Colors.transparent
                                : Theme.of(context).scaffoldBackgroundColor,
                            actions: [
                              // if (!isLocalArchive)
                              //   IconButton(
                              //       splashRadius: 20,
                              //       onPressed: () {},
                              //       icon: const Icon(
                              //         Icons.download_outlined,
                              //       )),
                              IconButton(
                                  splashRadius: 20,
                                  onPressed: () {
                                    _showDraggableMenu();
                                  },
                                  icon: Icon(
                                    Icons.filter_list_sharp,
                                    color:
                                        isNotFiltering ? null : Colors.yellow,
                                  )),
                              PopupMenuButton(itemBuilder: (context) {
                                return [
                                  if (widget.manga!.favorite)
                                    PopupMenuItem<int>(
                                        value: 0,
                                        child: Text(l10n.edit_categories)),
                                  if (!isLocalArchive)
                                    if (widget.manga!.favorite)
                                      PopupMenuItem<int>(
                                          value: 1, child: Text(l10n.migrate)),
                                  if (!isLocalArchive)
                                    PopupMenuItem<int>(
                                        value: 2, child: Text(l10n.share)),
                                ];
                              }, onSelected: (value) {
                                if (value == 0) {
                                  context.push("/categories", extra: (
                                    true,
                                    widget.manga!.isManga! ? 0 : 1
                                  ));
                                } else if (value == 1) {
                                } else if (value == 2) {
                                  final source = getSource(widget.manga!.lang!,
                                      widget.manga!.source!);
                                  String url = source.apiUrl!.isEmpty
                                      ? widget.manga!.link!
                                      : "${source.baseUrl}${widget.manga!.link!}";

                                  Share.share(url);
                                }
                              }),
                            ],
                          );
                  },
                )),
            body: SafeArea(
              child: Row(
                children: [
                  if (isTablet(context))
                    SizedBox(
                        width: mediaWidth(context, 0.4),
                        height: mediaHeight(context, 1),
                        child: SingleChildScrollView(
                            child: _bodyContainer(
                                chapterLength: chapters.length))),
                  Expanded(
                    child: DraggableScrollbar(
                        padding: const EdgeInsets.only(right: 7),
                        heightScrollThumb: 48.0,
                        backgroundColor: primaryColor(context),
                        scrollThumbBuilder: (backgroundColor, thumbAnimation,
                            labelAnimation, height,
                            {labelConstraints, labelText}) {
                          return FadeTransition(
                            opacity: thumbAnimation,
                            child: Container(
                              decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(20)),
                              height: height,
                              width: 8.0,
                            ),
                          );
                        },
                        scrollbarTimeToFade: const Duration(seconds: 2),
                        controller: _scrollController,
                        child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 0, bottom: 60),
                            itemCount: chapters.length + 1,
                            itemBuilder: (context, index) {
                              final l10n = l10nLocalizations(context)!;
                              int finalIndex = index - 1;
                              if (index == 0) {
                                return isTablet(context)
                                    ? Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Row(
                                              mainAxisAlignment: isLocalArchive
                                                  ? MainAxisAlignment
                                                      .spaceBetween
                                                  : MainAxisAlignment.start,
                                              children: [
                                                Container(
                                                  height: chapters.isEmpty
                                                      ? mediaHeight(context, 1)
                                                      : null,
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 8),
                                                    child: Text(
                                                      widget.manga!.isManga!
                                                          ? l10n.n_chapters(
                                                              chapters.length)
                                                          : l10n.n_episodes(
                                                              chapters.length),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                                if (isLocalArchive)
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5))),
                                                    icon: Icon(Icons.add,
                                                        color: secondaryColor(
                                                            context)),
                                                    label: Text(
                                                      l10n.add_chapters,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: secondaryColor(
                                                              context)),
                                                    ),
                                                    onPressed: () async {
                                                      await ref.watch(
                                                          importArchivesFromFileProvider(
                                                                  widget.manga)
                                                              .future);
                                                    },
                                                  )
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : _bodyContainer(
                                        chapterLength: chapters.length);
                              }
                              int reverseIndex = chapters.length -
                                  chapters.reversed.toList().indexOf(
                                      chapters.reversed.toList()[finalIndex]) -
                                  1;
                              final indexx =
                                  reverse ? reverseIndex : finalIndex;
                              return ChapterListTileWidget(
                                chapter: chapters[indexx],
                                chapterList: chapterList,
                                sourceExist: widget.sourceExist,
                              );
                            })),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Consumer(builder: (context, ref, child) {
              final chap = ref.watch(chaptersListStateProvider);
              bool getLength1 = chap.length == 1;
              bool checkFirstBookmarked =
                  chap.isNotEmpty && chap.first.isBookmarked! && getLength1;
              bool checkReadBookmarked =
                  chap.isNotEmpty && chap.first.isRead! && getLength1;
              final l10n = l10nLocalizations(context)!;
              return AnimatedContainer(
                curve: Curves.easeIn,
                decoration: BoxDecoration(
                    color: primaryColor(context).withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20))),
                duration: const Duration(milliseconds: 100),
                height: isLongPressed ? 70 : 0,
                width: mediaWidth(context, 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 70,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: () {
                              final chapters =
                                  ref.watch(chaptersListStateProvider);
                              isar.writeTxnSync(() {
                                for (var chapter in chapters) {
                                  chapter.isBookmarked = !chapter.isBookmarked!;
                                  isar.chapters.putSync(
                                      chapter..manga.value = widget.manga);
                                  chapter.manga.saveSync();
                                }
                              });
                              ref
                                  .read(isLongPressedStateProvider.notifier)
                                  .update(false);
                              ref
                                  .read(chaptersListStateProvider.notifier)
                                  .clear();
                            },
                            child: Icon(
                                checkFirstBookmarked
                                    ? Icons.bookmark_remove_outlined
                                    : Icons.bookmark_add_outlined,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color)),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 70,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: () {
                              final chapters =
                                  ref.watch(chaptersListStateProvider);
                              isar.writeTxnSync(() {
                                for (var chapter in chapters) {
                                  chapter.isRead = !chapter.isRead!;
                                  isar.chapters.putSync(
                                      chapter..manga.value = widget.manga);
                                  chapter.manga.saveSync();
                                }
                              });
                              ref
                                  .read(isLongPressedStateProvider.notifier)
                                  .update(false);
                              ref
                                  .read(chaptersListStateProvider.notifier)
                                  .clear();
                            },
                            child: Icon(
                                checkReadBookmarked
                                    ? Icons.remove_done_sharp
                                    : Icons.done_all_sharp,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color!)),
                      ),
                    ),
                    if (getLength1)
                      Expanded(
                        child: SizedBox(
                          height: 70,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () {
                                int index = chapters.indexOf(chap.first);
                                isar.writeTxnSync(() {
                                  for (var i = index + 1;
                                      i < chapters.length;
                                      i++) {
                                    chapters[i].isRead = true;
                                    isar.chapters.putSync(chapters[i]
                                      ..manga.value = widget.manga);
                                    chapters[i].manga.saveSync();
                                  }
                                  ref
                                      .read(isLongPressedStateProvider.notifier)
                                      .update(false);
                                  ref
                                      .read(chaptersListStateProvider.notifier)
                                      .clear();
                                });
                              },
                              child: Stack(
                                children: [
                                  Icon(Icons.done_outlined,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color!),
                                  Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Icon(Icons.arrow_downward_outlined,
                                          size: 11,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge!
                                              .color!))
                                ],
                              )),
                        ),
                      ),
                    if (!isLocalArchive)
                      Expanded(
                        child: SizedBox(
                          height: 70,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () {
                                isar.txnSync(() {
                                  for (var chapter
                                      in ref.watch(chaptersListStateProvider)) {
                                    final entries = isar.downloads
                                        .filter()
                                        .idIsNotNull()
                                        .chapterIdEqualTo(chapter.id)
                                        .findAllSync();
                                    if (entries.isEmpty ||
                                        !entries.first.isDownload!) {
                                      ref.watch(downloadChapterProvider(
                                          chapter: chapter));
                                    }
                                  }
                                });
                                ref
                                    .read(isLongPressedStateProvider.notifier)
                                    .update(false);
                                ref
                                    .read(chaptersListStateProvider.notifier)
                                    .clear();
                              },
                              child: Icon(
                                Icons.download_outlined,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color!,
                              )),
                        ),
                      ),
                    if (isLocalArchive)
                      Expanded(
                        child: SizedBox(
                          height: 70,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(
                                          l10n.delete_chapters,
                                        ),
                                        actions: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text(l10n.cancel)),
                                              const SizedBox(
                                                width: 15,
                                              ),
                                              TextButton(
                                                  onPressed: () async {
                                                    isar.writeTxnSync(() {
                                                      for (var chapter in ref.watch(
                                                          chaptersListStateProvider)) {
                                                        isar.chapters
                                                            .deleteSync(
                                                                chapter.id!);
                                                      }
                                                    });

                                                    ref
                                                        .read(
                                                            isLongPressedStateProvider
                                                                .notifier)
                                                        .update(false);
                                                    ref
                                                        .read(
                                                            chaptersListStateProvider
                                                                .notifier)
                                                        .clear();
                                                    if (mounted) {
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                  child: Text(l10n.delete)),
                                            ],
                                          )
                                        ],
                                      );
                                    });
                              },
                              child: Icon(
                                Icons.delete_outline_outlined,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color!,
                              )),
                        ),
                      )
                  ],
                ),
              );
            })),
      ],
    );
  }

  _showDraggableMenu() {
    late TabController tabBarController;
    tabBarController = TabController(length: 3, vsync: this);
    tabBarController.animateTo(0);
    DraggableMenu.open(
      context,
      Consumer(builder: (context, ref, child) {
        final scanlators =
            ref.watch(scanlatorsFilterStateProvider(widget.manga!));
        final l10n = l10nLocalizations(context)!;
        return DraggableMenu(
          ui: ClassicDraggableMenu(barItem: Container(), radius: 20),
          levels: [
            DraggableMenuLevel.ratio(
                ratio: scanlators.$1.isEmpty ? 1 / 3.6 : 1 / 3.3),
          ],
          fastDrag: false,
          minimizeBeforeFastDrag: false,
          child: DefaultTabController(
              length: 3,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).scaffoldBackgroundColor),
                  child: Column(
                    children: [
                      TabBar(
                        controller: tabBarController,
                        tabs: [
                          Tab(text: l10n.filter),
                          Tab(text: l10n.sort),
                          Tab(text: l10n.display),
                        ],
                      ),
                      Flexible(
                        child: TabBarView(
                            controller: tabBarController,
                            children: [
                              Consumer(builder: (context, ref, chil) {
                                return Column(
                                  children: [
                                    if (!isLocalArchive)
                                      ListTileChapterFilter(
                                          label: l10n.downloaded,
                                          type: ref.watch(
                                              chapterFilterDownloadedStateProvider(
                                                  mangaId: widget.manga!.id!)),
                                          onTap: () {
                                            ref
                                                .read(
                                                    chapterFilterDownloadedStateProvider(
                                                            mangaId: widget
                                                                .manga!.id!)
                                                        .notifier)
                                                .update();
                                          }),
                                    ListTileChapterFilter(
                                        label: l10n.unread,
                                        type: ref.watch(
                                            chapterFilterUnreadStateProvider(
                                                mangaId: widget.manga!.id!)),
                                        onTap: () {
                                          ref
                                              .read(
                                                  chapterFilterUnreadStateProvider(
                                                          mangaId:
                                                              widget.manga!.id!)
                                                      .notifier)
                                              .update();
                                        }),
                                    ListTileChapterFilter(
                                        label: l10n.bookmarked,
                                        type: ref.watch(
                                            chapterFilterBookmarkedStateProvider(
                                                mangaId: widget.manga!.id!)),
                                        onTap: () {
                                          ref
                                              .read(
                                                  chapterFilterBookmarkedStateProvider(
                                                          mangaId:
                                                              widget.manga!.id!)
                                                      .notifier)
                                              .update();
                                        }),
                                    if (scanlators.$1.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                  onPressed: () {
                                                    showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          return Consumer(
                                                              builder: (context,
                                                                  ref, child) {
                                                            final scanlators =
                                                                ref.watch(
                                                                    scanlatorsFilterStateProvider(
                                                                        widget
                                                                            .manga!));
                                                            return AlertDialog(
                                                              title: Text(
                                                                l10n.filter_scanlator_groups,
                                                              ),
                                                              content: SizedBox(
                                                                  width:
                                                                      mediaWidth(
                                                                          context,
                                                                          0.8),
                                                                  child: ListView
                                                                      .builder(
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        scanlators
                                                                            .$1
                                                                            .length,
                                                                    itemBuilder:
                                                                        (context,
                                                                            index) {
                                                                      return ListTileChapterFilter(
                                                                          label: scanlators.$1[
                                                                              index],
                                                                          type: scanlators.$3.contains(scanlators.$1[index])
                                                                              ? 2
                                                                              : 0,
                                                                          onTap:
                                                                              () {
                                                                            ref.read(scanlatorsFilterStateProvider(widget.manga!).notifier).setFilteredList(scanlators.$1[index]);
                                                                          });
                                                                    },
                                                                  )),
                                                              actions: [
                                                                Column(
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              Row(
                                                                            children: [
                                                                              TextButton(
                                                                                  onPressed: () {
                                                                                    ref.read(scanlatorsFilterStateProvider(widget.manga!).notifier).set([]);
                                                                                    Navigator.pop(context);
                                                                                  },
                                                                                  child: Text(
                                                                                    l10n.reset,
                                                                                    style: TextStyle(color: primaryColor(context)),
                                                                                  )),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            TextButton(
                                                                                onPressed: () async {
                                                                                  Navigator.pop(context);
                                                                                },
                                                                                child: Text(
                                                                                  l10n.cancel,
                                                                                  style: TextStyle(color: primaryColor(context)),
                                                                                )),
                                                                            TextButton(
                                                                                onPressed: () {
                                                                                  ref.read(scanlatorsFilterStateProvider(widget.manga!).notifier).set(scanlators.$3);
                                                                                  Navigator.pop(context);
                                                                                },
                                                                                child: Text(
                                                                                  l10n.filter,
                                                                                  style: TextStyle(color: primaryColor(context)),
                                                                                )),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                )
                                                              ],
                                                            );
                                                          });
                                                        });
                                                  },
                                                  child: Text(l10n
                                                      .filter_scanlator_groups)),
                                            ),
                                          ],
                                        ),
                                      )
                                  ],
                                );
                              }),
                              Consumer(builder: (context, ref, chil) {
                                final reverse = ref
                                    .read(sortChapterStateProvider(
                                            mangaId: widget.manga!.id!)
                                        .notifier)
                                    .isReverse();
                                final reverseChapter = ref.watch(
                                    sortChapterStateProvider(
                                        mangaId: widget.manga!.id!));
                                return Column(
                                  children: [
                                    for (var i = 0; i < 3; i++)
                                      ListTileChapterSort(
                                        label: _getSortNameByIndex(i, context),
                                        reverse: reverse,
                                        onTap: () {
                                          ref
                                              .read(sortChapterStateProvider(
                                                      mangaId:
                                                          widget.manga!.id!)
                                                  .notifier)
                                              .set(i);
                                        },
                                        showLeading: reverseChapter.index == i,
                                      ),
                                  ],
                                );
                              }),
                              Consumer(builder: (context, ref, chil) {
                                return Column(
                                  children: [
                                    RadioListTile(
                                      dense: true,
                                      title: Text(l10n.source_title),
                                      value: "e",
                                      groupValue: "e",
                                      selected: true,
                                      onChanged: (value) {},
                                    ),
                                    RadioListTile(
                                      dense: true,
                                      title: Text(l10n.chapter_number),
                                      value: "ej",
                                      groupValue: "e",
                                      selected: false,
                                      onChanged: (value) {},
                                    ),
                                  ],
                                );
                              }),
                            ]),
                      ),
                    ],
                  ),
                ),
              )),
        );
      }),
      barrier: true,
    );
  }

  String _getSortNameByIndex(int index, BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    if (index == 0) {
      return l10n.by_source;
    } else if (index == 1) {
      return l10n.by_chapter_number;
    }
    return l10n.by_upload_date;
  }

  Widget _bodyContainer({required int chapterLength}) {
    final l10n = l10nLocalizations(context)!;
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.05),
                Theme.of(context).scaffoldBackgroundColor
              ],
              stops: const [0, .3],
            ),
          ),
        ),
        Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: mediaWidth(context, 1),
                  child: Row(
                    children: [
                      _coverCard(),
                      Expanded(child: _titles()),
                    ],
                  ),
                ),
                if (isLocalArchive)
                  Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                          onPressed: () {
                            _editLocaleArchiveInfos();
                          },
                          icon: const CircleAvatar(
                              child: Icon(Icons.edit_outlined))))
              ],
            ),
            if (!isLocalArchive) _actionFavouriteAndWebview(),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.manga!.description != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ReadMoreWidget(
                        text: widget.manga!.description!,
                        onChanged: (value) {
                          setState(() {
                            _expanded = value;
                          });
                        },
                      ),
                    ),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: widget.manga!.genre!.isEmpty
                          ? const SizedBox(
                              height: 30,
                            )
                          : _expanded || isTablet(context)
                              ? Wrap(
                                  children: [
                                    for (var i = 0;
                                        i < widget.manga!.genre!.length;
                                        i++)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 2, right: 2, bottom: 5),
                                        child: SizedBox(
                                          height: 30,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                elevation: 0,
                                                backgroundColor: Colors.grey
                                                    .withOpacity(0.2),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5))),
                                            onPressed: () {},
                                            child: Text(
                                              widget.manga!.genre![i],
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: isLight(context)
                                                      ? Colors.black
                                                      : Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      for (var i = 0;
                                          i < widget.manga!.genre!.length;
                                          i++)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 2, right: 2, bottom: 5),
                                          child: SizedBox(
                                            height: 30,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  elevation: 0,
                                                  backgroundColor: Colors.grey
                                                      .withOpacity(0.2),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5))),
                                              onPressed: () {},
                                              child: Text(
                                                widget.manga!.genre![i],
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: isLight(context)
                                                        ? Colors.black
                                                        : Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )),
                  if (!isTablet(context))
                    Column(
                      children: [
                        //Description
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: isLocalArchive
                                ? MainAxisAlignment.spaceBetween
                                : MainAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  widget.manga!.isManga!
                                      ? l10n.n_chapters(chapterLength)
                                      : l10n.n_episodes(chapterLength),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isLocalArchive)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5))),
                                  icon: Icon(Icons.add,
                                      color: secondaryColor(context)),
                                  label: Text(
                                    l10n.add_chapters,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: secondaryColor(context)),
                                  ),
                                  onPressed: () async {
                                    await ref.watch(
                                        importArchivesFromFileProvider(
                                                widget.manga)
                                            .future);
                                  },
                                )
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (chapterLength == 0)
              Container(
                  width: mediaWidth(context, 1),
                  height: mediaHeight(context, 1),
                  color: Theme.of(context).scaffoldBackgroundColor)
          ],
        ),
      ],
    );
  }

  Widget _coverCard() {
    final imageProvider = widget.manga!.customCoverImage != null
        ? MemoryImage(widget.manga!.customCoverImage as Uint8List)
            as ImageProvider
        : CachedNetworkImageProvider(widget.manga!.imageUrl!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 20),
      child: GestureDetector(
        onTap: () {
          _openImage(imageProvider);
        },
        child: SizedBox(
          width: 65 * 1.5,
          height: 65 * 2.3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.manga!.name!,
            style: const TextStyle(
              fontSize: 20,
            )),
        widget.titleDescription!,
      ],
    );
  }

  Widget _actionFavouriteAndWebview() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(child: widget.action!),
          Expanded(
            child: StreamBuilder(
                stream: isar.trackPreferences
                    .filter()
                    .syncIdIsNotNull()
                    .watch(fireImmediately: true),
                builder: (context, snapshot) {
                  List<TrackPreference>? entries =
                      snapshot.hasData ? snapshot.data! : [];
                  if (entries.isEmpty) {
                    return Container();
                  }
                  return SizedBox(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          elevation: 0),
                      onPressed: () {
                        _trackingDraggableMenu(entries);
                      },
                      child: StreamBuilder(
                          stream: isar.tracks
                              .filter()
                              .idIsNotNull()
                              .mangaIdEqualTo(widget.manga!.id!)
                              .watch(fireImmediately: true),
                          builder: (context, snapshot) {
                            final l10n = l10nLocalizations(context)!;
                            List<Track>? trackRes =
                                snapshot.hasData ? snapshot.data : [];
                            bool isNotEmpty = trackRes!.isNotEmpty;
                            Color color = isNotEmpty
                                ? primaryColor(context)
                                : secondaryColor(context);
                            return Column(
                              children: [
                                Icon(
                                  isNotEmpty
                                      ? Icons.done
                                      : Icons.screen_rotation_alt_rounded,
                                  size: 20,
                                  color: color,
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  isNotEmpty
                                      ? trackRes.length == 1
                                          ? l10n.one_tracker
                                          : l10n.n_tracker(trackRes.length)
                                      : l10n.tracking,
                                  style: TextStyle(fontSize: 11, color: color),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }),
                    ),
                  );
                }),
          ),
          Expanded(
            child: SizedBox(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 0),
                onPressed: () {
                  final manga = widget.manga!;
                  final source =
                      getSource(widget.manga!.lang!, widget.manga!.source!);
                  String url = source.apiUrl!.isEmpty
                      ? widget.manga!.link!
                      : "${source.baseUrl}${widget.manga!.link!}";

                  Map<String, String> data = {
                    'url': url,
                    'sourceId': source.id.toString(),
                    'title': manga.name!
                  };
                  context.push("/mangawebview", extra: data);
                },
                child: Column(
                  children: [
                    Icon(
                      Icons.public,
                      size: 20,
                      color: secondaryColor(context),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'WebView',
                      style: TextStyle(
                          fontSize: 11, color: secondaryColor(context)),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  _openImage(ImageProvider imageProvider) {
    showDialog(
        context: context,
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: PhotoViewGallery.builder(
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.transparent),
                    itemCount: 1,
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: imageProvider,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: 2.0,
                      );
                    },
                    loadingBuilder: (context, event) {
                      return const ProgressCenter();
                    },
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Row(
                    children: [
                      if (!isLocalArchive)
                        if (widget.manga!.customCoverImage != null)
                          PopupMenuButton(
                            itemBuilder: (context) {
                              return [
                                const PopupMenuItem<int>(
                                    value: 0, child: Text("Delete")),
                                const PopupMenuItem<int>(
                                    value: 1, child: Text("Edit")),
                              ];
                            },
                            onSelected: (value) async {
                              final manga = widget.manga!;
                              if (value == 0) {
                                isar.writeTxnSync(() {
                                  isar.mangas
                                      .putSync(manga..customCoverImage = null);
                                });
                              } else if (value == 1) {
                                FilePickerResult? result =
                                    await FilePicker.platform.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: [
                                      'png',
                                      'jpg',
                                      'jpeg'
                                    ]);
                                if (result != null) {
                                  if (result.files.first.size < 5000000) {
                                    final customCoverImage =
                                        File(result.files.first.path!)
                                            .readAsBytesSync();
                                    isar.writeTxnSync(() {
                                      isar.mangas.putSync(manga
                                        ..customCoverImage = customCoverImage);
                                    });
                                  }
                                }
                              }
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                  child: Icon(Icons.edit_outlined)),
                            ),
                          ),
                      // IconButton(
                      //     onPressed: () async {
                      //       Uint8List? bytes;
                      //       if (isLocalArchive) {
                      //         bytes =
                      //             widget.manga!.customCoverImage as Uint8List?;
                      //       }
                      //       await Share.shareXFiles([
                      //         XFile.fromData(bytes!,
                      //             name: widget.manga!.name,
                      //             mimeType: 'image/jpeg')
                      //       ]);
                      //     },
                      //     icon: const CircleAvatar(child: Icon(Icons.share))),

                      if (isLocalArchive ||
                          widget.manga!.customCoverImage == null)
                        IconButton(
                            onPressed: () async {
                              FilePickerResult? result =
                                  await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: [
                                    'png',
                                    'jpg',
                                    'jpeg'
                                  ]);
                              if (result != null) {
                                if (result.files.first.size < 5000000) {
                                  final manga = widget.manga!;
                                  final customCoverImage =
                                      File(result.files.first.path!)
                                          .readAsBytesSync();
                                  isar.writeTxnSync(() {
                                    isar.mangas.putSync(manga
                                      ..customCoverImage = customCoverImage);
                                  });
                                  if (mounted) {
                                    Navigator.pop(context);
                                  }
                                }
                              }
                            },
                            icon: const CircleAvatar(
                                child: Icon(Icons.edit_outlined))),
                    ],
                  ),
                )
              ],
            ),
          );
        });
  }

  _editLocaleArchiveInfos() {
    final l10n = l10nLocalizations(context)!;
    TextEditingController? name =
        TextEditingController(text: widget.manga!.name!);
    TextEditingController? description =
        TextEditingController(text: widget.manga!.description!);
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              l10n.edit,
            ),
            content: SizedBox(
              height: 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 15),
                          child: Text(l10n.name),
                        ),
                        TextFormField(
                          controller: name,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 15),
                          child: Text(l10n.description),
                        ),
                        TextFormField(
                          controller: description,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(l10n.cancel)),
                  const SizedBox(
                    width: 15,
                  ),
                  TextButton(
                      onPressed: () {
                        isar.writeTxnSync(() {
                          final manga = widget.manga!;
                          manga.description = description.text;
                          manga.name = name.text;
                          isar.mangas.putSync(manga);
                        });
                        Navigator.pop(context);
                      },
                      child: Text(l10n.edit)),
                ],
              )
            ],
          );
        });
  }

  _trackingDraggableMenu(List<TrackPreference>? entries) {
    DraggableMenu.open(
        context,
        DraggableMenu(
          ui: SoftModernDraggableMenu(radius: 20, barItem: Container()),
          child: Material(
            color: isLight(context)
                ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9)
                : !isar.settings.getSync(227)!.pureBlackDarkMode!
                    ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9)
                    : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.separated(
                padding: const EdgeInsets.all(0),
                itemCount: entries!.length,
                primary: false,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return StreamBuilder(
                      stream: isar.tracks
                          .filter()
                          .idIsNotNull()
                          .syncIdEqualTo(entries[index].syncId)
                          .mangaIdEqualTo(widget.manga!.id!)
                          .watch(fireImmediately: true),
                      builder: (context, snapshot) {
                        List<Track>? trackRes =
                            snapshot.hasData ? snapshot.data : [];

                        return trackRes!.isNotEmpty
                            ? TrackerWidget(
                                mangaId: widget.manga!.id!,
                                trackPreference: entries[index],
                                trackRes: trackRes.first,
                                isManga: widget.manga!.isManga!)
                            : TrackListile(
                                text: l10nLocalizations(context)!.add_tracker,
                                onTap: () async {
                                  final trackSearch =
                                      await trackersSearchraggableMenu(
                                    context,
                                    isManga: widget.manga!.isManga!,
                                    track: Track(
                                        status: TrackStatus.planToRead,
                                        syncId: entries[index].syncId!,
                                        title: widget.manga!.name!),
                                  ) as TrackSearch?;
                                  if (trackSearch != null) {
                                    await ref
                                        .read(trackStateProvider(
                                                track: null,
                                                isManga: widget.manga!.isManga!)
                                            .notifier)
                                        .setTrackSearch(
                                            trackSearch,
                                            widget.manga!.id!,
                                            entries[index].syncId!);
                                  }
                                },
                                id: entries[index].syncId!,
                                entries: const []);
                      });
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const Divider();
                },
              ),
            ),
          ),
        ));
  }
}
