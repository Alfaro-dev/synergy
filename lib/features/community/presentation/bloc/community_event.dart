import 'package:equatable/equatable.dart';

sealed class CommunityEvent extends Equatable {
  const CommunityEvent();

  @override
  List<Object?> get props => [];
}

final class CommunityFetchRequested extends CommunityEvent {
  const CommunityFetchRequested({this.before});
  final String? before;
}

final class CommunityRefreshRequested extends CommunityEvent {
  const CommunityRefreshRequested();
}

final class CommunityMetadataRequested extends CommunityEvent {
  const CommunityMetadataRequested({required this.communityId});
  final String communityId;
}
