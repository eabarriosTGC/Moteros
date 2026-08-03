/// Search Events for the map search feature.
library;

import 'package:equatable/equatable.dart';
import '../../domain/entities/search_result_entity.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

final class SearchPlace extends SearchEvent {
  final String query;

  const SearchPlace(this.query);

  @override
  List<Object?> get props => [query];
}

final class SelectPlace extends SearchEvent {
  final SearchResultEntity result;

  const SelectPlace(this.result);

  @override
  List<Object?> get props => [result];
}

final class ClearSearch extends SearchEvent {
  const ClearSearch();
}
