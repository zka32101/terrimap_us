import 'package:flutter/foundation.dart';

/// ストアのランキング(iOS は Game Center、Android は Google Play ゲーム)へ、エンドレスの自己ベストを送る口。
/// 端末内の記録([AppState.endless])が正本。ここは送るだけで、失敗してもアプリは止めない。
/// 実体(プラグインとストア側のリーダーボード登録)をつなぐまでは [NoopLeaderboard]。
abstract class LeaderboardService {
  const LeaderboardService();

  /// [rank]: 波数×1,000,000＋スコア(core の `EndlessResult.rank`)。ストア側は「大きいほど上位」で登録する。
  Future<void> submit(int rank);
}

class NoopLeaderboard extends LeaderboardService {
  const NoopLeaderboard();
  @override
  Future<void> submit(int rank) async {}
}

/// 送った値を記録するだけの偽物(テスト用)。
@visibleForTesting
class RecordingLeaderboard extends LeaderboardService {
  final List<int> sent = [];
  RecordingLeaderboard();
  @override
  Future<void> submit(int rank) async => sent.add(rank);
}
