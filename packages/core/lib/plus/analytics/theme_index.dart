import '../../models/collection_item.dart';
import '../models/item_aspect.dart';
import '../models/media_path.dart';

/// Themes read from the genres every source already ships, so exploring works
/// before the user has tagged anything. Keywords match whole words only.
enum BuiltInTheme {
  dark(PathAspect.atmosphere, <String>[
    'horror',
    'gothic',
    'gore',
    'dark fantasy',
  ]),
  tense(PathAspect.atmosphere, <String>['thriller', 'suspense', 'stealth']),
  lighthearted(PathAspect.atmosphere, <String>[
    'comedy',
    'humor',
    'humour',
    'parody',
    'party',
    'family',
  ]),
  cozy(PathAspect.atmosphere, <String>[
    'slice of life',
    'iyashikei',
    'cozy',
    'farming',
  ]),
  emotional(PathAspect.atmosphere, <String>['drama', 'tragedy', 'melodrama']),
  surreal(PathAspect.atmosphere, <String>[
    'surreal',
    'avant garde',
    'psychedelic',
    'experimental',
  ]),
  space(PathAspect.setting, <String>[
    'science fiction',
    'sci fi',
    'space',
    'space opera',
  ]),
  fantasyWorlds(PathAspect.setting, <String>[
    'fantasy',
    'sword and sorcery',
    'isekai',
  ]),
  historical(PathAspect.setting, <String>[
    'historical',
    'history',
    'western',
    'samurai',
  ]),
  dystopia(PathAspect.setting, <String>[
    'cyberpunk',
    'dystopia',
    'dystopian',
    'post apocalyptic',
    'steampunk',
  ]),
  school(PathAspect.setting, <String>['school', 'school life', 'campus']),
  supernatural(PathAspect.setting, <String>[
    'supernatural',
    'paranormal',
    'vampire',
    'vampires',
    'mythology',
    'ghost',
    'ghosts',
  ]),
  love(PathAspect.themes, <String>['romance', 'romantic', 'love']),
  war(PathAspect.themes, <String>['war', 'military', 'warfare']),
  mind(PathAspect.themes, <String>[
    'psychological',
    'philosophy',
    'philosophical',
    'existential',
  ]),
  crime(PathAspect.themes, <String>[
    'crime',
    'detective',
    'mafia',
    'heist',
    'legal',
  ]),
  comingOfAge(PathAspect.themes, <String>[
    'coming of age',
    'bildungsroman',
    'youth',
  ]),
  machines(PathAspect.themes, <String>['mecha', 'robot', 'robots']),
  competition(PathAspect.themes, <String>[
    'sports',
    'sport',
    'racing',
    'martial arts',
  ]),
  mystery(PathAspect.structure, <String>['mystery', 'puzzle', 'whodunit']),
  journey(PathAspect.structure, <String>[
    'adventure',
    'exploration',
    'open world',
    'travel',
    'point and click',
  ]),
  action(PathAspect.structure, <String>[
    'action',
    'shooter',
    'hack and slash',
    'fighting',
    'platform',
  ]),
  strategy(PathAspect.structure, <String>[
    'strategy',
    'tactics',
    'tactical',
    'rts',
    'tbs',
  ]),
  rolePlaying(PathAspect.structure, <String>['role playing', 'rpg']),
  trueStories(PathAspect.structure, <String>[
    'documentary',
    'biography',
    'memoir',
    'true crime',
    'nonfiction',
  ]);

  const BuiltInTheme(this.aspect, this.keywords);

  final PathAspect aspect;
  final List<String> keywords;
}

/// Either a built-in theme or a label the user typed; custom labels compare
/// case-insensitively so "Melancholic" and "melancholic" are one tag.
class ThemeKey {
  const ThemeKey.builtIn(BuiltInTheme this.builtIn)
    : aspect = null,
      label = null;

  const ThemeKey.custom(PathAspect this.aspect, String this.label)
    : builtIn = null;

  final BuiltInTheme? builtIn;
  final PathAspect? aspect;
  final String? label;

  PathAspect get aspectOf => builtIn?.aspect ?? aspect ?? PathAspect.themes;

  String get _identity {
    final BuiltInTheme? b = builtIn;
    if (b != null) return 'b:${b.name}';
    return 'c:${aspect?.value}:${label?.toLowerCase()}';
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeKey && other._identity == _identity;

  @override
  int get hashCode => _identity.hashCode;
}

class ThemeIndex {
  ThemeIndex._(this._items);

  factory ThemeIndex.build({
    required Iterable<CollectionItem> items,
    required Iterable<ItemAspectTag> tags,
  }) {
    final Map<int, CollectionItem> byId = <int, CollectionItem>{
      for (final CollectionItem i in items) i.id: i,
    };
    final Map<ThemeKey, List<CollectionItem>> index =
        <ThemeKey, List<CollectionItem>>{};
    void put(ThemeKey key, CollectionItem item) {
      final List<CollectionItem> list = index.putIfAbsent(
        key,
        () => <CollectionItem>[],
      );
      if (!list.any((CollectionItem i) => i.id == item.id)) list.add(item);
    }

    for (final CollectionItem item in byId.values) {
      for (final BuiltInTheme t in themesFor(item.genres ?? const <String>[])) {
        put(ThemeKey.builtIn(t), item);
      }
    }
    for (final ItemAspectTag tag in tags) {
      final CollectionItem? item = byId[tag.itemId];
      if (item != null) put(ThemeKey.custom(tag.aspect, tag.label), item);
    }
    return ThemeIndex._(index);
  }

  final Map<ThemeKey, List<CollectionItem>> _items;

  static Set<BuiltInTheme> themesFor(Iterable<String> genres) {
    final Set<BuiltInTheme> found = <BuiltInTheme>{};
    for (final String genre in genres) {
      final String padded = ' ${_normalize(genre)} ';
      for (final BuiltInTheme t in BuiltInTheme.values) {
        if (found.contains(t)) continue;
        for (final String kw in t.keywords) {
          if (padded.contains(' $kw ')) {
            found.add(t);
            break;
          }
        }
      }
    }
    return found;
  }

  /// Tags under [aspect], the most populated first.
  List<ThemeKey> keysFor(PathAspect aspect) {
    final List<ThemeKey> keys = _items.keys
        .where((ThemeKey k) => k.aspectOf == aspect)
        .toList();
    keys.sort((ThemeKey a, ThemeKey b) {
      final int byCount = itemsFor(b).length.compareTo(itemsFor(a).length);
      if (byCount != 0) return byCount;
      // Built-ins keep enum order; custom labels follow alphabetically.
      final BuiltInTheme? ba = a.builtIn;
      final BuiltInTheme? bb = b.builtIn;
      if (ba != null && bb != null) return ba.index.compareTo(bb.index);
      if (ba != null) return -1;
      if (bb != null) return 1;
      return (a.label ?? '').toLowerCase().compareTo(
        (b.label ?? '').toLowerCase(),
      );
    });
    return keys;
  }

  List<CollectionItem> itemsFor(ThemeKey key) =>
      _items[key] ?? const <CollectionItem>[];

  bool get isEmpty => _items.isEmpty;

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
