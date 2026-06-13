# PhotoWindow / 摄影窗口

PhotoWindow 是一个摄影事件提醒类 iOS MVP 原型。第一版聚焦“什么时候值得拍”和“提前提醒”，使用 SwiftUI、MVVM、本地 mock data 与本地通知占位实现。

## 当前功能

- 首页展示今日推荐、评分最高窗口、类别入口和特殊事件。
- 类别页按星空、飞机、风光、人像、毕业照等分类展示拍摄窗口。
- 详情页展示评分、推荐理由、天气快照、相关事件、收藏和提醒开关。
- 详情页支持“有用 / 一般 / 没用”推荐反馈和可选 comment。
- 地点页展示 Brisbane Airport、UQ St Lucia Campus、Lake Moogerah、South Bank。
- 地点页支持自定义地点、收藏地点、地点类型筛选和地点详情。
- 提醒设置页支持启用/停用、修改最低评分、修改提前提醒时间、删除 mock 规则。
- 提醒设置页提供本地通知测试入口，可创建 5 秒/1 分钟测试提醒、清除全部提醒并查看待触发列表。
- 特殊事件提醒支持 mock 事件关注关键词、事件重要程度 badge、提醒合并摘要逻辑。
- v0.2 支持由 mock 天气 forecast、mock 天文数据和地点条件自动生成拍摄窗口。
- v0.3 支持用户偏好、关注类别/地点、自动匹配提醒和即将提醒列表。
- v0.4 支持内测反馈、本地基础埋点和提醒可靠性测试。
- v0.5 支持自定义地点、地点级拍摄窗口和地点级提醒规则。
- v0.6 支持特殊事件数据源层、本地 JSON 事件库、事件去重、可信度和特殊事件驱动的 ShootingWindow。
- v0.7 支持从事件服务器拉取 special events，成功后缓存到本地，服务器不可用时自动使用离线缓存或内置 JSON。
- v0.8 / v0.9 server 已拆分到独立仓库；当前仓库只维护 iOS App，App 继续通过统一 API envelope 读取 metadata、special events 和 incremental sync。
- v0.9 支持 iOS API 环境切换、NetworkClient、文件缓存、增量 sync、DataDebugView 和 fallback 状态展示。
- v1.1 新增：SpecialEvent 字段解码兼容性增强、航空来源展示与定位：支持 sourceType 显示/中文映射、confidenceLevel、importanceLevel、sourceName/URL/更新时间在列表和详情中展示；地点搜索改为服务器代理 `/api/v1/locations/search` 与 `/api/v1/locations/reverse`，不可用时自动回退 mock。
- v1.0 Beta Candidate 支持推荐解释 `RecommendationResult`、分类评分权重 `scoring_rules.json`、提醒质量控制、勿扰时段、每日最大提醒数、正式 onboarding，以及 Admin 事件推荐预览。
- Repository 协议已预留，当前实现为 in-memory mock 与 UserDefaults 本地保存，后续可替换为 Supabase、Firebase 或自建后端。

## 运行方式

1. 安装完整 Xcode。
2. 选择 Xcode 作为开发者目录：

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. 打开 `PhotoWindow.xcodeproj`。
4. 选择 `PhotoWindow` scheme 和 iOS 17+ 模拟器运行。

iOS App 默认使用已部署的公网事件服务器：

```text
http://152.67.112.15:15176
```

server 端已经独立维护；本仓库不再包含 `/server`。如果要回到本机开发，可以在“偏好 → 数据调试”里切到 `localSimulator`、`localNetwork` 或 `custom`。iOS Simulator 使用 `localSimulator`，也就是 `http://localhost:3000`。真机局域网调试可以用 `custom` 输入电脑局域网 IP，例如 `http://192.168.1.20:3000`。

可在 Xcode scheme 的 Environment Variables 中设置：

```text
PHOTOWINDOW_API_ENVIRONMENT=publicServer
PHOTOWINDOW_API_BASE_URL=http://152.67.112.15:15176
PHOTOWINDOW_USE_REMOTE_SPECIAL_EVENTS=true
```

支持的 API 环境：

- `publicServer`: `http://152.67.112.15:15176`
- `localSimulator`: `http://localhost:3000`
- `localNetwork`: `http://192.168.1.100:3000`
- `custom`: 在 DataDebugView 或 Xcode environment variable 中输入任意 baseURL

Debug 阶段允许访问 HTTP 公网事件服务器；Release/线上环境应使用 HTTPS。

项目已包含共享 `PhotoWindow` scheme。当前开发环境已在 Xcode 26.3 / iOS Simulator 26.3 下验证。可运行：

```bash
xcodebuild -scheme PhotoWindow -destination 'platform=iOS Simulator,name=iPhone 17' test
```

也可以运行不依赖 iOS Simulator 的核心业务层 smoke verification：

```bash
bash Scripts/verify_core.sh
```

如需手动安装到模拟器：

```bash
xcrun simctl boot "iPhone 17"
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/PhotoWindow-*/Build/Products/Debug-iphonesimulator/PhotoWindow.app
xcrun simctl launch booted com.photowindow.app
```

## 架构

- `Models/`：核心数据模型和枚举。
- `Repositories/`：Repository 协议与 mock 实现。
- `Services/`：mock 数据、拍摄窗口生成、评分逻辑、特殊事件 ingestion/去重、NetworkClient、文件缓存、增量同步、本地通知。
- `ViewModels/`：SwiftUI 页面状态和业务动作。
- `Views/`：Tab、首页、类别、详情、地点、提醒设置。
- `Views/Components/`：卡片、评分徽章、类别入口、天气指标和主题样式。

## MVP 边界

本版本不包含登录、真实后端、真实天气 API、真实航空 API、地图、社交 feed、聊天、约拍交易、支付或 TestFlight 配置。

## v0.2 天气 / 天文驱动窗口生成

- `WeatherRepository` 现在按地点返回一组 `WeatherSnapshot` forecast；`MockWeatherRepository` 使用 30 分钟内存缓存。
- `AstronomyRepository` 提供 `AstronomySnapshot`，包含日出、日落、黄金时刻、蓝调时刻、月相和月亮照明；`MockAstronomyRepository` 使用 24 小时内存缓存。
- `ShootingWindowGenerationService` 根据地点、天气、天文和类别生成窗口：星空看夜间/云量/降雨/月光/光污染，风光看日出日落/黄金时刻/云量/降雨/风速，毕业照和人像看柔光/无雨/低风/舒适温度，飞机摄影继续使用 mock event + 天气评分。
- `HomeViewModel` 启动时加载地点、天气和天文数据并生成窗口，按评分排序；失败时 fallback 到本地 mock windows。
- `HomeView` 显示 loading、数据更新于和 fallback 提示。

本地通知通过 `UNUserNotificationCenter` 实现接口和占位调用。模拟器或真机必须授权通知，且系统是否展示通知取决于运行环境和触发时间。

## 特殊事件提醒

- `EventWatchlistItem` 使用本地 mock data 管理关注关键词，例如 A380、Special Livery、Meteor Shower、Graduation Season 和 Fire Sunset。
- `ShootingEvent` 增加 `EventImportanceLevel`：普通、值得关注、稀有、必拍。
- 首页特殊事件区域会优先展示命中 watchlist、稀有/必拍和高评分窗口。
- 详情页展示事件重要程度、命中关键词、建议提醒时间和提醒是否会合并进摘要。
- `ReminderMergeService` 会把同一天、2 小时内的多个本地提醒合并为一条摘要提醒；当前仍是本地逻辑，不接远程推送。

## v0.6 特殊事件数据源引擎

- `SpecialEvent` 统一描述特殊拍摄事件，包含类别、事件类型、地点、时间、重要程度、可信度、tags、来源类型、来源名称、来源 URL、更新时间和创建时间。
- `SpecialEventRepository` 提供统一协议，当前实现包括 `LocalJSONSpecialEventRepository` 和 `MockSpecialEventRepository`；`RemoteJSONSpecialEventRepository` / `APISpecialEventRepository` 作为未来真实数据源占位。
- `PhotoWindow/Resources/special_events_seed.json` 是 MVP 本地事件库，包含 Brisbane Airport 特殊涂装、A380、Lake Moogerah 流星雨/银河、UQ Graduation、South Bank 火烧云、Kangaroo Point 清晨低雾和 City 蓝调夜景窗口。
- `SpecialEventConfidenceLevel` 支持 low / medium / high；`importanceLevel` 继续复用 `EventImportanceLevel`：normal、worthWatching、rare、mustShoot。
- `SpecialEvent` 解码适配 server 新增字段，新增 `status`/`qualityScore`/`qualityReasons` 不影响解析，`published` 以外事件会在客户端按规则过滤显示。
- `SpecialEventDeduplicationService` 使用地点、类别、时间重叠、标题和 tags 相似度做 MVP 去重，并保留重要程度更高、可信度更高、更新时间更新的事件。
- `SpecialEventIngestionService` 从 repository 获取事件，按地点 / 类别 / 时间过滤，并把事件转换成 `ShootingEvent` 供 `ShootingWindowGenerationService` 使用。
- `ShootingWindowGenerationService` 支持 `SpecialEvent + WeatherSnapshot + AstronomySnapshot` 直接生成事件驱动窗口；rare / mustShoot 会提高评分，low confidence 会降低评分，reason tags 会加入特殊涂装、A380、流星雨、毕业季、火烧云可能、清晨低雾等事件原因。
- `ShootingWindowScoringService.scoreSpecialEventWindow` 综合事件重要程度、可信度、云量、降雨概率、能见度、风速和类别特定因素评分。
- `SpecialEventsView` 按 Today / Tomorrow / This Week 展示未来特殊事件，`SpecialEventDetailView` 展示来源、更新时间、推荐理由、tags、关联 ShootingWindow、提醒和收藏。
- `AlertMatchingService` 支持用事件 title / description / tags 匹配用户 watchlist keywords，并避免同一事件重复生成提醒；特殊事件通知文案会显示“必拍事件 / 稀有事件 / 特殊事件”。

## v0.7 远程特殊事件数据

- server 端已从本仓库拆分；iOS App 只依赖已配置 baseURL 的公开接口，不在 App 内直接请求第三方数据源。
- `NetworkClient` 是统一网络层，支持 baseURL、timeout、GET、统一 API envelope decoding 和 `APIError` 分类。
- `RemoteSpecialEventRepository` 使用 `NetworkClient` 从 server 拉取事件 JSON，支持 `fetchSpecialEvents`、category/location 过滤、`fetchMetadata` 和 `syncSpecialEvents(since:)`。
- `SpecialEventCacheService` 使用 FileManager 缓存到 `Application Support / PhotoWindowCache / special_events_cache.json`，缓存 events、dataVersion、lastUpdated、cachedAt 和 source。
- `SpecialEventSyncService` 是 App 的事件数据入口：先读缓存给 UI，再请求 metadata；dataVersion 变化时全量 fetch，dataVersion 相同但 lastUpdated 更新时调用 sync 增量合并 updated/deleted。
- `SpecialEventDataValidator` 会在 iOS 端轻量校验事件；单条坏数据会跳过并记录 skipped count，不让整个 App 崩溃。
- 远程连接失败时，首页会显示“无法连接事件服务器，当前使用离线缓存。”，并自动使用离线缓存；没有缓存时 fallback 到 `LocalJSONSpecialEventRepository` 的内置示例数据。
- `HomeView` 和 `SpecialEventsView` 会显示“事件数据来自：事件服务器 / 离线缓存 / 内置示例数据 / Mock 数据”。
- Debug 配置允许本地 HTTP 开发请求。正式部署时应使用 HTTPS，并移除开发阶段的 App Transport Security 本地 HTTP 例外。

## v0.8 / v0.9 API 环境与同步

- 事件运营后台和真实数据源接入在独立 server 仓库维护；iOS App 只读取已发布且未删除事件。
- 公开 API 使用统一 response envelope：`data`、`meta`、`error`。
- `/api/v1/special-events` 支持 `limit`、`offset`、`sort=startTime`、`sort=-startTime`，并返回 count/total/dataVersion/lastUpdated。
- `/api/v1/special-events/sync?since=...` 返回 since 之后 updated events 和 deleted event ids。
- `/api/v1/metadata` 返回 eventDataVersion、lastUpdated、eventCount、publishedEventCount 和 serverTime。
- `APIConfig.current` 根据 `PHOTOWINDOW_API_ENVIRONMENT` 和 `PHOTOWINDOW_API_BASE_URL` 选择环境。
- fallback 逻辑保持不变：远程成功使用 `remoteServer`，server 失败使用 `localCache`，没有缓存时使用 `bundledJSON`，最后才用 `mock`。
- UI 继续显示当前事件数据来源：事件服务器、离线缓存、内置示例数据或 Mock 数据。
- `DataDebugView` 可从“偏好 → 数据调试”进入，查看 current environment、baseURL、dataSource、dataVersion、cache event count、last remote fetch、last successful fetch、last error、skipped invalid event count 和 cache file path，也可以刷新远程事件数据、清空缓存后重新拉取、重新加载 bundled JSON。

## v1.0 Beta Candidate 推荐与提醒质量

- `RecommendationResult` 让 `ShootingWindow` 不再只有分数，还包含 `scoreLevel`、`confidenceLevel`、推荐原因、扣分原因、风险提示、适合人群、推荐文案、建议到场时间和是否建议默认提醒。
- `PhotoWindow/Resources/scoring_rules.json` 配置 astro、aviation、landscape、graduation、portrait、cityscape、wildlife 的评分权重；`ScoringRuleConfigService` 负责加载配置，失败时 fallback 到默认配置。
- `ShootingWindowScoringService` 使用分类权重输出 0-100 分和解释结果。星空更看重云量、月光、光污染；航空更看重事件重要度、能见度和降雨；毕业照/人像更看重柔光、风速、无雨和舒适度。
- `NotificationQualityService` 在创建本地通知前做质量过滤：每日最大提醒数量、勿扰时段、同地点同类别合并、低评分跳过、low confidence 默认跳过，`mustShoot` 可按偏好覆盖。
- `NotificationPreference` 保存 `dailyMaxNotifications`、`quietHoursStart`、`quietHoursEnd`、`minScoreForNotification`、`allowMustShootOverride` 和 `mergeNearbyNotifications`。
- `DebugNotificationView` 和 `DataDebugView` 会显示当前提醒质量规则、最近被跳过的通知及原因、评分配置加载状态、当前 onboarding 偏好和通知阈值。
- 偏好页升级为最多 5 步 onboarding：选择主要摄影类别、选择常用地点、设置最低推荐分数、设置提醒偏好、请求通知权限；任一步可跳过，保存后写入本地偏好并同步提醒规则。
- 首页卡片显示评分等级、可信度、top 3 推荐原因和特殊事件 badge；窗口详情页显示推荐原因、扣分原因、风险提示、适合人群、建议到场时间和是否建议开启提醒。
- `SpecialEventsView` 显示 importance、confidence 和轻量推荐预览，帮助判断事件发布后的推荐倾向。
- 独立 server 提供 `POST /api/v1/admin/preview/special-event`，后台表单的 `Preview` 按钮会校验 draft 并返回预计评分、推荐原因、扣分原因、是否触发提醒、建议提醒时间和命中的 watchlist 关键词。该预览是运营用的简化评分，不替代 iOS 端完整推荐算法。

## v0.3 个性化订阅与自动提醒

- `UserPreference` 保存关注类别、收藏地点、默认最低评分、默认提前提醒时间和每日摘要开关。
- 偏好页可选择关注类别和常用地点，保存后会生成或更新对应 `AlertRule`。
- `AlertRule` 增加 `locationId` 和 `createdAt`，当前规则与用户偏好通过 UserDefaults 本地保存。
- `AlertMatchingService` 会用生成的 `ShootingWindow` 自动匹配启用的提醒规则，并避免同一个窗口重复生成通知。
- `NotificationService` 支持批量创建本地通知、取消单个提醒和取消全部提醒。
- 首页按用户关注类别和收藏地点优先展示高分窗口，并增加“今日摄影机会摘要”和“即将提醒”模块。
- `UpcomingNotificationsView` 展示即将触发的本地提醒，可进入窗口详情或取消提醒。

## v0.4 内测反馈、基础埋点与提醒可靠性测试

- `Feedback` 记录窗口推荐反馈：`useful`、`okay`、`notUseful`、可选 comment、用户和窗口 ID。
- `FeedbackRepository` 当前使用 UserDefaults 本地保存，同一用户对同一窗口的最新反馈会覆盖旧反馈。
- `AnalyticsEvent` 和 `AnalyticsService` 本地记录并 print：`app_opened`、`home_window_viewed`、`category_opened`、`window_detail_opened`、`alert_enabled`、`alert_disabled`、`notification_clicked`、`window_bookmarked`、`feedback_submitted`。
- 首页“今日摄影机会摘要”显示当天高分窗口数量、最佳机会和评分；没有高分窗口时提示关注未来几天。
- `NotificationService` 支持测试通知、取消全部通知和读取 pending notifications。
- `DebugNotificationView` 提供 5 秒后测试提醒、1 分钟后测试提醒、清除全部提醒和待触发列表。

## v0.5 自定义地点、收藏地点与地点级窗口

- `ShootingLocation` 增加收藏状态、适合类别、创建/更新时间，并支持 `portraitSpot` 和 `custom` 地点类型。
- `SavedLocationRepository` 使用 UserDefaults + Codable 保存用户地点，支持新增、更新、删除、收藏切换和收藏地点查询；协议边界可替换为 Supabase、Firebase 或自建后端。
- `LocationSearchService` 预留搜索、反向地理编码和当前位置接口；MVP 当前用 mock 搜索结果，定位不可用时可手动输入经纬度。
- `LocationSearchService` 现已接入服务器代理：`/api/v1/locations/search` 与 `/api/v1/locations/reverse`，搜索和反查优先走公开 API，失败时回退本地 mock 并保留现有手输/当前定位工作流。
- `AddLocationView` 支持搜索地点、使用当前位置、手动经纬度、自定义名称、地点类型、适合类别、光污染等级、备注和保存。
- `LocationDetailView` 展示地点信息、收藏状态、适合类别、未来 7 天最佳拍摄窗口、已开启提醒规则和备注；可编辑、删除、收藏或为地点创建提醒规则。
- `ExploreLocationsView` 升级为“我的收藏地点 / 所有保存地点 / 添加地点 / 地点类型筛选”的管理入口。
- `HomeViewModel` 基于保存地点自动生成窗口，优先展示收藏地点和用户关注类别；没有保存地点时提示添加第一个拍摄地点。
- `ShootingWindowGenerationService` 根据地点类型决定默认类别：机场偏航空，暗空偏星空，校园偏毕业照/人像，风景区偏风光，城市偏城市风光/风光，野生动物区域偏 wildlife，人像点偏人像/毕业照。
- 地点级 `AlertRule` 由地点详情页创建，当前仍是本地规则和本地通知匹配，不接真实后端。

## 后续迭代方向

- 接入 Supabase 或 Firebase，并替换 mock repositories。
- 在独立 server 端接入天气、天文、航空和日历数据源；iOS App 只读取 server 聚合后的 special events。
- 增加 MapKit 地点选择。
- 增加日历导出、分享事件卡片和更多自定义提醒规则。

## 参考

- [MVP_CHECKLIST.md](MVP_CHECKLIST.md)：规格覆盖与验收证据。
