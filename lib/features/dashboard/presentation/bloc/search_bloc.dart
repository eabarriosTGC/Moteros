/// SearchBloc — manages place search with debounce, cache, and rate throttle.
///
/// Features:
/// - 300ms debounce on search input (Completer-based)
/// - In-memory cache with 5-minute TTL
/// - Rate throttle: max 1 req/sec at Bloc level
/// - SelectPlace → map centers on coordinate, temporary marker auto-clears after 5s
library;

import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../data/datasources/nominatim_datasource.dart';
import '../../domain/entities/search_result_entity.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Internal cache entry with TTL.
class _CacheEntry {
  final List<SearchResultEntity> results;
  final DateTime timestamp;

  const _CacheEntry({required this.results, required this.timestamp});

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final NominatimDatasource _datasource;

  // ── Debounce (Completer-based: each new event cancels the previous) ──
  Completer<void>? _debounceCompleter;

  // ── In-memory cache ──
  final Map<String, _CacheEntry> _cache = {};

  // ── Rate throttle (1 req/sec) ──
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minRequestInterval = Duration(seconds: 1);

  // ── Timer for auto-clearing PlaceSelected state ──
  Timer? _clearTimer;

  SearchBloc({required this._datasource}) : super(const SearchInitial()) {
    on<SearchPlace>(_onSearchPlace);
    on<SelectPlace>(_onSelectPlace);
    on<ClearSearch>((event, emit) {
      _clearTimer?.cancel();
      emit(const SearchInitial());
    });
  }

  /// Handle a search query with 300ms debounce.
  Future<void> _onSearchPlace(
    SearchPlace event,
    Emitter<SearchState> emit,
  ) async {
    // Cancel any pending debounce
    _debounceCompleter?.complete();
    _debounceCompleter = null;

    final query = event.query.trim();

    // Empty/whitespace query → clear
    if (query.isEmpty) {
      emit(const SearchInitial());
      return;
    }

    // Check cache synchronously — if hit, return immediately
    final cached = _cache[query];
    if (cached != null && !cached.isExpired) {
      emit(SearchResultsLoaded(cached.results));
      return;
    }

    // Debounce: create a new completer and wait 300ms
    final completer = Completer<void>();
    _debounceCompleter = completer;

    await Future.delayed(const Duration(milliseconds: 300));

    // If this completer was completed (cancelled by a newer event), bail out
    if (completer.isCompleted) return;

    await _performSearch(query, emit);
  }

  /// Perform the actual API search with rate throttle.
  Future<void> _performSearch(
    String query,
    Emitter<SearchState> emit,
  ) async {
    // Re-check cache (may have been populated while debouncing)
    final cached = _cache[query];
    if (cached != null && !cached.isExpired) {
      emit(SearchResultsLoaded(cached.results));
      return;
    }

    // Rate throttle: ensure min 1 second between requests
    final elapsed = DateTime.now().difference(_lastRequestTime);
    if (elapsed < _minRequestInterval) {
      await Future.delayed(_minRequestInterval - elapsed);
    }

    emit(const SearchLoading());

    try {
      _lastRequestTime = DateTime.now();
      final results = await _datasource.search(query);

      // Store in cache
      _cache[query] = _CacheEntry(
        results: results,
        timestamp: DateTime.now(),
      );

      emit(SearchResultsLoaded(results));
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  /// Handle a place selection: emit PlaceSelected, auto-clear after 5s.
  Future<void> _onSelectPlace(
    SelectPlace event,
    Emitter<SearchState> emit,
  ) async {
    _clearTimer?.cancel();

    emit(PlaceSelected(event.result));

    // Auto-clear after 5 seconds
    _clearTimer = Timer(const Duration(seconds: 5), () {
      if (!isClosed) {
        add(ClearSearch());
      }
    });
  }

  @override
  Future<void> close() {
    _debounceCompleter?.complete();
    _debounceCompleter = null;
    _clearTimer?.cancel();
    return super.close();
  }
}
