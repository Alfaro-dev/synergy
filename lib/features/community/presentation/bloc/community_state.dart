import 'package:equatable/equatable.dart';
import '../../domain/entities/community.dart';

sealed class CommunityState extends Equatable {
  const CommunityState();

  @override
  List<Object?> get props => [];
}

final class CommunityInitial extends CommunityState {
  const CommunityInitial();
}

final class CommunityLoading extends CommunityState {
  const CommunityLoading();
}

final class CommunityLoaded extends CommunityState {
  const CommunityLoaded({
    required this.communities,
    required this.hasMore,
    this.nextBefore,
  });

  @override
  List<Object?> get props => [communities, hasMore, nextBefore];

  final List<Community> communities;
  final bool hasMore;
  final String? nextBefore;
}

final class CommunityError extends CommunityState {
  const CommunityError({required this.message});

  @override
  List<Object?> get props => [message];

  final String message;
}
