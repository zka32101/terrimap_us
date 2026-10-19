import 'package:app_common_kit/app_common_kit.dart';
import 'package:in_app_review/in_app_review.dart';

/// ストアのレビュー画面（`in_app_review`）。キットはプラグインに依存しないので、アプリ側で渡す。
class InAppReviewBackend implements ReviewBackend {
  final InAppReview _r = InAppReview.instance;

  @override
  Future<bool> isAvailable() => _r.isAvailable();

  @override
  Future<void> requestReview() => _r.requestReview();
}

/// レビューを頼むタイミングの制御。条件はキットの既定（初回から7日・良い体験3回・前回から120日・生涯3回）。
Future<ReviewPromptService> createReviewPrompt(String appId) async {
  final s = ReviewPromptService(store: SharedPreferencesReviewStore(appId), backend: InAppReviewBackend());
  await s.load();
  return s;
}
