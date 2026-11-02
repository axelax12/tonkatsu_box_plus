import 'dart:io';

import 'package:core/database/dao/collection_dao.dart';
import 'package:core/database/migrations/migration_registry.dart';
import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/profile.dart';
import 'package:core/plus/analytics/group_pick.dart';
import 'package:core/plus/database/goals_dao.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common/sqflite.dart';

import '../../../core/services/profile_service.dart';
import '../../../shared/constants/platform_features.dart';
import '../../insights/providers/insights_providers.dart';
import '../../settings/providers/profile_provider.dart';

enum LibraryAccess { ready, outdated, missing, failed }

class ProfileLibrary {
  const ProfileLibrary(this.access, [this.items = const <CollectionItem>[]]);

  final LibraryAccess access;
  final List<CollectionItem> items;
}

final Logger _log = Logger('Together');

/// Another profile's library, read straight from its file and closed again.
/// A file still on an older schema is skipped: its columns may not exist yet.
final AutoDisposeFutureProviderFamily<ProfileLibrary, String>
otherProfileLibraryProvider = FutureProvider.autoDispose
    .family<ProfileLibrary, String>((Ref ref, String profileId) async {
      if (kIsWebBuild) return const ProfileLibrary(LibraryAccess.missing);
      final String path = await ref
          .read(profileServiceProvider)
          .getDatabasePath(profileId);
      if (!File(path).existsSync()) {
        return const ProfileLibrary(LibraryAccess.missing);
      }
      Database? db;
      try {
        final Database opened = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        db = opened;
        final int version = await opened.getVersion();
        if (version < MigrationRegistry.latestVersion) {
          return const ProfileLibrary(LibraryAccess.outdated);
        }
        final List<CollectionItem> items = await CollectionDao.withMediaDaos(
          () async => opened,
        ).getAllCollectionItemsWithData();
        return ProfileLibrary(LibraryAccess.ready, items);
      } on Exception catch (e, stack) {
        _log.warning('Could not read profile $profileId', e, stack);
        return const ProfileLibrary(LibraryAccess.failed);
      } finally {
        await db?.close();
      }
    });

typedef Voter = ({String id, String name});

enum TogetherStep { setup, handoff, voting, results }

class TogetherState {
  const TogetherState({
    this.profileIds = const <String>{},
    this.guests = const <String>[],
    this.filters = const PickFilters(),
    this.step = TogetherStep.setup,
    this.ballot = const <PickCandidate>[],
    this.voters = const <Voter>[],
    this.voterIndex = 0,
    this.cardIndex = 0,
    this.votes = const <String, Map<String, Vote>>{},
  });

  /// Other profiles taking part; the current one always does.
  final Set<String> profileIds;
  final List<String> guests;
  final PickFilters filters;
  final TogetherStep step;
  final List<PickCandidate> ballot;
  final List<Voter> voters;
  final int voterIndex;
  final int cardIndex;
  final Map<String, Map<String, Vote>> votes;

  Voter? get currentVoter =>
      voterIndex < voters.length ? voters[voterIndex] : null;

  PickCandidate? get currentCard =>
      cardIndex < ballot.length ? ballot[cardIndex] : null;

  TogetherState copyWith({
    Set<String>? profileIds,
    List<String>? guests,
    PickFilters? filters,
    TogetherStep? step,
    List<PickCandidate>? ballot,
    List<Voter>? voters,
    int? voterIndex,
    int? cardIndex,
    Map<String, Map<String, Vote>>? votes,
  }) {
    return TogetherState(
      profileIds: profileIds ?? this.profileIds,
      guests: guests ?? this.guests,
      filters: filters ?? this.filters,
      step: step ?? this.step,
      ballot: ballot ?? this.ballot,
      voters: voters ?? this.voters,
      voterIndex: voterIndex ?? this.voterIndex,
      cardIndex: cardIndex ?? this.cardIndex,
      votes: votes ?? this.votes,
    );
  }
}

class TogetherController extends AutoDisposeNotifier<TogetherState> {
  /// Long enough to have a real choice, short enough to vote on in a minute.
  static const int ballotSize = 8;

  static const int maxGuests = 8;

  static const String _guestPrefix = 'guest:';

  @override
  TogetherState build() => const TogetherState();

  void toggleProfile(String id) {
    final Set<String> ids = Set<String>.of(state.profileIds);
    if (!ids.remove(id)) ids.add(id);
    state = state.copyWith(profileIds: ids);
  }

  void addGuest(String name) {
    final String clean = name.trim();
    if (clean.isEmpty || state.guests.length >= maxGuests) return;
    state = state.copyWith(guests: <String>[...state.guests, clean]);
  }

  void removeGuest(int index) {
    final List<String> guests = List<String>.of(state.guests)..removeAt(index);
    state = state.copyWith(guests: guests);
  }

  void setFilters(PickFilters filters) =>
      state = state.copyWith(filters: filters);

  void start(List<PickCandidate> pool) {
    final ProfilesData data = ref.read(profilesDataProvider);
    final Profile me = data.currentProfile;
    final List<Voter> voters = <Voter>[
      (id: me.id, name: me.name),
      for (final Profile p in data.profiles)
        if (p.id != me.id && state.profileIds.contains(p.id))
          (id: p.id, name: p.name),
      for (int i = 0; i < state.guests.length; i++)
        (id: '$_guestPrefix$i', name: state.guests[i]),
    ];
    state = state.copyWith(
      ballot: GroupPick.ballot(pool, size: ballotSize),
      voters: voters,
      voterIndex: 0,
      cardIndex: 0,
      votes: const <String, Map<String, Vote>>{},
      step: TogetherStep.handoff,
    );
  }

  void beginTurn() => state = state.copyWith(step: TogetherStep.voting);

  void vote(Vote vote) {
    final Voter? voter = state.currentVoter;
    final PickCandidate? card = state.currentCard;
    if (voter == null || card == null) return;
    final Map<String, Map<String, Vote>> votes =
        <String, Map<String, Vote>>{
          ...state.votes,
          voter.id: <String, Vote>{...?state.votes[voter.id], card.key: vote},
        };
    final int nextCard = state.cardIndex + 1;
    if (nextCard < state.ballot.length) {
      state = state.copyWith(votes: votes, cardIndex: nextCard);
      return;
    }
    final int nextVoter = state.voterIndex + 1;
    state = state.copyWith(
      votes: votes,
      cardIndex: 0,
      voterIndex: nextVoter,
      step: nextVoter < state.voters.length
          ? TogetherStep.handoff
          : TogetherStep.results,
    );
  }

  /// Steps back one card within the current turn only: once the phone has
  /// been handed over, earlier votes stay private.
  void undo() {
    if (state.step != TogetherStep.voting || state.cardIndex == 0) return;
    state = state.copyWith(cardIndex: state.cardIndex - 1);
  }

  void voteAgain() => state = state.copyWith(
    voterIndex: 0,
    cardIndex: 0,
    votes: const <String, Map<String, Vote>>{},
    step: TogetherStep.handoff,
  );

  void newRound() => state = state.copyWith(
    step: TogetherStep.setup,
    ballot: const <PickCandidate>[],
    votes: const <String, Map<String, Vote>>{},
  );
}

final AutoDisposeNotifierProvider<TogetherController, TogetherState>
togetherProvider =
    NotifierProvider.autoDispose<TogetherController, TogetherState>(
      TogetherController.new,
    );

/// Every participant's library, the current profile first so its copy of a
/// shared work is the one that can be opened.
class TogetherLibraries {
  const TogetherLibraries({
    required this.libraries,
    required this.access,
    required this.gameSecondsById,
  });

  final Map<String, List<CollectionItem>> libraries;
  final Map<String, LibraryAccess> access;
  final Map<int, int> gameSecondsById;
}

final AutoDisposeFutureProvider<TogetherLibraries> togetherLibrariesProvider =
    FutureProvider.autoDispose<TogetherLibraries>((Ref ref) async {
      final String me = ref.watch(currentProfileProvider).id;
      final Set<String> others = ref.watch(
        togetherProvider.select((TogetherState s) => s.profileIds),
      );
      final Map<String, List<CollectionItem>> libraries =
          <String, List<CollectionItem>>{
            me: await ref.watch(libraryItemsProvider.future),
          };
      final Map<String, LibraryAccess> access = <String, LibraryAccess>{
        me: LibraryAccess.ready,
      };
      for (final String id in others) {
        final ProfileLibrary library = await ref.watch(
          otherProfileLibraryProvider(id).future,
        );
        access[id] = library.access;
        if (library.access == LibraryAccess.ready) {
          libraries[id] = library.items;
        }
      }
      final List<int> gameIds = <int>{
        for (final List<CollectionItem> items in libraries.values)
          for (final CollectionItem i in items)
            if (i.mediaType == MediaType.game) i.externalId,
      }.toList();
      final GoalsDao goals = ref.read(goalsDaoProvider);
      return TogetherLibraries(
        libraries: libraries,
        access: access,
        gameSecondsById: await goals.getTimeToBeat(gameIds),
      );
    });

typedef TogetherPool = ({
  List<PickCandidate> pool,
  Set<MediaType> availableTypes,
  Map<String, LibraryAccess> access,
});

final AutoDisposeFutureProvider<TogetherPool> togetherPoolProvider =
    FutureProvider.autoDispose<TogetherPool>((Ref ref) async {
      final TogetherLibraries data = await ref.watch(
        togetherLibrariesProvider.future,
      );
      final PickFilters filters = ref.watch(
        togetherProvider.select((TogetherState s) => s.filters),
      );
      final List<PickCandidate> everything = GroupPick.candidates(
        libraries: data.libraries,
        gameSecondsById: data.gameSecondsById,
      );
      return (
        pool: GroupPick.candidates(
          libraries: data.libraries,
          filters: filters,
          gameSecondsById: data.gameSecondsById,
        ),
        availableTypes: <MediaType>{
          for (final PickCandidate c in everything) c.item.mediaType,
        },
        access: data.access,
      );
    });
