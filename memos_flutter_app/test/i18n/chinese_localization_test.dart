import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  group('Chinese localization', () {
    test('zh-Hans keeps key UI labels in Chinese', () {
      final t = AppLocale.zhHans.build();

      expect(t.strings.onboarding.modeLocalLabel, '本地模式');
      expect(t.strings.onboarding.modeServerLabel, '服务器模式');
      expect(
        t.strings.common.serverVersionProbeHint,
        '登录前，仅会探测所选服务端版本的核心 API。',
      );
      expect(t.strings.login.field.tokenLabel, '令牌（PAT）');
      expect(t.strings.legacy.msg_query, '查询参数');
      expect(t.strings.legacy.msg_body_json, '请求体（JSON）');
      expect(t.strings.legacy.msg_webhooks, '网络回调');
      expect(t.strings.legacy.msg_comments(widget_commentCount: 3), '3 条评论');
      expect(t.strings.legacy.msg_web_api_key, 'Web API 密钥');
      expect(t.strings.legacy.msg_back_2, '返回');
      expect(t.strings.legacy.msg_energy_restored, '⚡ 能量已恢复');
      expect(
        t.strings.legacy.msg_webhooks_not_supported_server,
        '当前服务器不支持网络回调',
      );
    });

    test('zh-Hant-TW keeps key UI labels in Traditional Chinese', () {
      final t = AppLocale.zhHantTw.build();

      expect(
        t.strings.common.serverVersionProbeHint,
        '登入前，僅會探測所選伺服器版本的核心 API。',
      );
      expect(t.strings.login.field.tokenLabel, '權杖（PAT）');
      expect(t.strings.legacy.msg_query, '查詢參數');
      expect(t.strings.legacy.msg_body_json, '請求本文（JSON）');
      expect(t.strings.legacy.msg_webhooks, '網路回呼');
      expect(t.strings.legacy.msg_restored, '已恢復');
      expect(t.strings.legacy.msg_comments(widget_commentCount: 3), '3 則評論');
      expect(t.strings.legacy.msg_web_api_key, 'Web API 金鑰');
      expect(t.strings.legacy.msg_back_2, '返回');
      expect(t.strings.legacy.msg_energy_restored, '⚡ 能量已恢復');
      expect(
        t.strings.legacy.msg_webhooks_not_supported_server,
        '目前伺服器不支援網路回呼',
      );
    });
  });
}
