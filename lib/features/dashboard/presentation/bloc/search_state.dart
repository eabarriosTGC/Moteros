/// Search States for the map search feature.
library;

import 'package:equatable/equatable.dart';
import '../../domain/entities/search_result_entity.dart';

sealed class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

final class SearchInitial extends SearchState {
  const SearchInitial();
}

final class SearchLoading extends SearchState {
  const SearchLoading();
}

final class SearchResultsLoaded extends SearchState {
  final List<SearchResultEntity> results;

  const SearchResultsLoaded(this.results);

  @override
  List<Object?> get props => [results];
}

final class PlaceSelected extends SearchState {
  final SearchResultEntity result;

  const PlaceSelected(this.result);

  @override
  List<Object?> get props => [result];
}

final class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}
