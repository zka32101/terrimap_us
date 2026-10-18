import 'package:app_common_kit/app_common_kit.dart' show LegalLinks;

/// プライバシーポリシー・利用規約の URL。公開したら、ここに入れる（空の間は、設定画面に出ない）。
/// 文面は、専門家の確認を経て決める（app_common_kit の `docs/法務文書_確認用チェックリスト.md`）。
const privacyPolicyUrl = '';
const termsUrl = '';

LegalLinks? get legalLinks => privacyPolicyUrl.isEmpty && termsUrl.isEmpty
    ? null
    : LegalLinks(
        privacyPolicyUrl: privacyPolicyUrl.isEmpty ? null : privacyPolicyUrl,
        termsUrl: termsUrl.isEmpty ? null : termsUrl,
      );
