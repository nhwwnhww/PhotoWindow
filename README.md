# PhotoWindow / 摄影窗口

PhotoWindow 是一个摄影事件提醒类 iOS MVP 原型。第一版聚焦“什么时候值得拍”和“提前提醒”，使用 SwiftUI、MVVM、本地 mock data 与本地通知占位实现。

## 当前功能

- 首页展示今日推荐、评分最高窗口、类别入口和特殊事件。
- 类别页按星空、飞机、风光、人像、毕业照等分类展示拍摄窗口。
- 详情页展示评分、推荐理由、天气快照、相关事件、收藏和提醒开关。
- 地点页展示 Brisbane Airport、UQ St Lucia Campus、Lake Moogerah。
- 提醒设置页支持启用/停用、修改最低评分、修改提前提醒时间、删除 mock 规则。
- Repository 协议已预留，当前实现为 in-memory mock，后续可替换为 Supabase、Firebase 或自建后端。

## 运行方式

1. 安装完整 Xcode。
2. 选择 Xcode 作为开发者目录：

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. 打开 `PhotoWindow.xcodeproj`。
4. 选择 `PhotoWindow` scheme 和 iOS 17+ 模拟器运行。

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
- `Services/`：mock 数据、评分逻辑、本地通知。
- `ViewModels/`：SwiftUI 页面状态和业务动作。
- `Views/`：Tab、首页、类别、详情、地点、提醒设置。
- `Views/Components/`：卡片、评分徽章、类别入口、天气指标和主题样式。

## MVP 边界

本版本不包含登录、真实后端、真实天气 API、真实航空 API、地图、社交 feed、聊天、约拍交易、支付或 TestFlight 配置。

本地通知通过 `UNUserNotificationCenter` 实现接口和占位调用。模拟器或真机必须授权通知，且系统是否展示通知取决于运行环境和触发时间。

## 后续迭代方向

- 接入 Supabase 或 Firebase，并替换 mock repositories。
- 接入天气、天文和航空数据源，按地点和日期缓存事件。
- 增加 MapKit 地点选择。
- 增加用户反馈：有用 / 没用 / 我去了 / 我没去。
- 增加日历导出、分享事件卡片和更多自定义提醒规则。

## 参考

- [MVP_CHECKLIST.md](MVP_CHECKLIST.md)：规格覆盖与验收证据。
