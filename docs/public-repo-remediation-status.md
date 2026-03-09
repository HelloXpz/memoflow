# 公开仓整改完成状态

本文档用于冻结当前公开仓整改结果，明确“已经完成什么”和“接下来该去哪里继续做私有商业化开发”。

## 当前结论
- 公开仓四批整改已完成，当前仓库已具备公开主仓形态。
- 公开壳层已收敛到 `bundle/provider` seam，不再为未来订阅或 iOS 商业运行态承载分支逻辑。
- 未来支付、订阅、权益、StoreKit、商品配置、App Store 商业化代码不应继续写入本仓库。
- 下一阶段若开始支付相关开发，应转到私有仓 / 私有 overlay，在保留的 seam 上接入。

## 四批整改结果

### 第一批：建立公开 / 私有边界
- 新增公开边界目录：
  - `memos_flutter_app/lib/module_boundary/`
  - `memos_flutter_app/lib/access_boundary/`
  - `memos_flutter_app/lib/platform_capabilities/`
  - `memos_flutter_app/lib/private_hooks/`
- 固定公开壳层唯一 provider seam：
  - `memos_flutter_app/lib/private_hooks/private_extension_bundle_provider.dart`
- 固定唯一 overlay seam：
  - `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`
- `memos_flutter_app/lib/app.dart` 只做 `onAppReady(...)` 通知，不承载商业分支。
- `memos_flutter_app/lib/features/settings/settings_screen.dart` 只渲染 bundle 返回的扩展 entry，不做 capability 判断。

### 第二批：去除共享商业状态污染
- 删除公开共享状态里的皇冠持久化字段与写入逻辑：
  - `memos_flutter_app/lib/data/models/app_preferences.dart`
  - `memos_flutter_app/lib/state/settings/preferences_provider.dart`
- `memos_flutter_app/lib/features/settings/donation_dialog.dart` 保留公开赞赏入口与二维码资源，但不再读写皇冠状态。
- `memos_flutter_app/lib/features/settings/settings_screen.dart` 资料区不再展示 crown UI。
- donor 致谢展示继续保留在公开仓。

### 第三批：补文档、补 guardrail、清重复目录
- 新增边界与私有 overlay 文档：
  - `docs/private-extension-boundary.md`
  - `docs/private-overlay-workflow.md`
  - `docs/private-bundle-template.md`
  - `docs/public-contributor-checklist.md`
- 新增 guardrail 脚本与工作流：
  - `.github/scripts/public_repo_guardrails.ps1`
  - `.github/workflows/public_repo_guardrails.yml`
- guardrail 已区分强拦截与弱告警，并限制公共壳层 import / 分支方式。
- 清理根目录历史重复 runtime 文件：
  - `lib/data/models/shortcut.dart`
  - `lib/data/models/user_setting.dart`
- `tree.txt` 已同步刷新，不再保留这些重复文件引用。

### 第四批：收口与交付
- 增加本状态文档，作为公开仓整改完成记录。
- `README_EN.md` 增加整改状态文档入口。
- `public_repo_guardrails` workflow 增加手动触发入口，便于后续随时做公开仓验收。

## 当前公开仓允许保留的内容
- 公开主应用运行代码与现有 Android / Windows 构建链路。
- 公开赞赏入口与二维码资源。
- donor wall / donor announcement / donor acknowledgement。
- 非商业语义的平台适配与通用 UI 扩展点。

## 当前公开仓明确禁止的内容
- 订阅、支付、权益、商品、恢复购买、收据校验、StoreKit 商业运行逻辑。
- 把商业状态塞入以下共享层：
  - `AppPreferences`
  - session / account 模型
  - update config
  - 通用 repository
- 在以下公共壳层文件写商业分支：
  - `memos_flutter_app/lib/app.dart`
  - `memos_flutter_app/lib/main.dart`
  - `memos_flutter_app/lib/features/settings/settings_screen.dart`
  - `memos_flutter_app/lib/features/home/main_home_page.dart`
  - `memos_flutter_app/lib/features/home/app_drawer.dart`

## 下一步应该怎么做
- 不要直接在本公开仓开始写支付 SDK、StoreKit、商品 ID、权益判断。
- 建立私有仓或私有 overlay，并只覆盖：
  - `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`
- 在私有仓中接入：
  - `private_billing`
  - `private_entitlements`
  - `private_ios_runtime`
- 若未来需要私有“订阅中心”入口，应由私有 bundle 决定是否返回 `SettingsEntryContribution`，而不是让公共 `settings_screen.dart` 做判断。

## 验收基线
已执行并通过的针对性验收包括：
- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter test test/data/models/app_preferences_test.dart`
- `flutter test test/private_hooks/private_extension_bundle_provider_test.dart`
- `flutter test test/private_hooks/app_ready_hook_test.dart`
- `flutter test test/private_hooks/public_shell_contract_test.dart`
- `flutter test test/features/settings/settings_screen_test.dart`
- `flutter test test/data/api --reporter expanded`
- `powershell -ExecutionPolicy Bypass -File .github/scripts/public_repo_guardrails.ps1`

## 已知仓库现状
- `flutter analyze` 仍存在与本次整改无关的历史问题。
- 全量 `flutter test` 仍有一个既有失败：`memos_flutter_app/test/widget_test.dart`。
- 以上两项不阻断本次公开 / 私有边界整改结论，但在未来常规质量治理中仍建议单独处理。

## 最终判定
- 若问题是“公开仓整改是否完成”：是，当前可判定为完成。
- 若问题是“现在能否直接在这个公开仓写支付代码”：否。
- 正确做法是：以当前公开仓为基线，转入私有仓继续实现商业化能力。
