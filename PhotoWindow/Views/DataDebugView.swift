import SwiftUI

struct DataDebugView: View {
    @StateObject private var viewModel: DataDebugViewModel

    init(viewModel: DataDebugViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                environmentSection
                diagnosticsSection
                apiDiagnosticsSection
                aviationDiagnosticsSection
                cacheSection
                recommendationDiagnosticsSection
                notificationDiagnosticsSection
                actionSection

                if let message = viewModel.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.photoAccent)
                        .photoCardStyle()
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("数据调试")
        .photoInlineNavigationTitle()
        .task {
            viewModel.load()
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .padding(10)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("事件数据调试")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("检查 API 环境、缓存文件和最近一次同步结果。")
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API 环境")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Picker("Environment", selection: $viewModel.selectedEnvironment) {
                ForEach(APIEnvironment.allCases) { environment in
                    Text(environment.displayName).tag(environment)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.selectedEnvironment == .custom {
                TextField("http://152.67.112.15:15176", text: $viewModel.customBaseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.white)
            }

            detailRow("current environment", viewModel.selectedEnvironment.rawValue)
            detailRow("baseURL", viewModel.activeBaseURL)

            Button {
                viewModel.saveAPISettings()
            } label: {
                Label("保存 API 配置", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("同步状态")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            detailRow("dataSource", viewModel.dataSource.displayName)
            detailRow("syncState", viewModel.syncState.displayName)
            detailRow("dataVersion", viewModel.dataVersion ?? "-")
            detailRow("event count", "\(viewModel.eventCount)")
            detailRow("last remote fetch", format(viewModel.lastRemoteFetchTime))
            detailRow("last successful fetch", format(viewModel.lastSuccessfulFetchTime))
            detailRow("last error", viewModel.lastError ?? "-")
            detailRow("skipped invalid events", "\(viewModel.skippedInvalidEventCount)")
        }
        .photoCardStyle()
    }

    private var apiDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API 诊断")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Button {
                Task { await viewModel.runAPIDiagnostics() }
            } label: {
                Label(viewModel.isCheckingAPI ? "诊断中" : "检查 public API", systemImage: "stethoscope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
            .disabled(viewModel.isLoading || viewModel.isCheckingAPI)

            if viewModel.apiDiagnostics.isEmpty {
                Text("尚未运行 API 诊断。")
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
            } else {
                ForEach(viewModel.apiDiagnostics) { result in
                    apiDiagnosticRow(result)
                }
            }
        }
        .photoCardStyle()
    }

    private var aviationDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("aviationAPI")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            detailRow("aviation event count", "\(viewModel.aviationEventCount)")
            detailRow("lastUpdated", format(viewModel.aviationLastUpdated))
            detailRow("last error", viewModel.aviationLastError ?? "-")
        }
        .photoCardStyle()
    }

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("缓存")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            detailRow("cache event count", "\(viewModel.cacheInfo?.eventCount ?? 0)")
            detailRow("cache dataVersion", viewModel.cacheInfo?.dataVersion ?? "-")
            detailRow("cache lastUpdated", format(viewModel.cacheInfo?.lastUpdated))
            detailRow("cachedAt", format(viewModel.cacheInfo?.cachedAt))
            detailRow("cache file path", viewModel.cacheInfo?.filePath ?? "-")
        }
        .photoCardStyle()
    }

    private var recommendationDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("推荐规则")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            detailRow("scoring config loaded", viewModel.scoringConfigLoaded ? "yes" : "fallback defaults")
            detailRow("scoring config error", viewModel.scoringConfigError ?? "-")
            detailRow("onboarding preference", viewModel.onboardingPreferenceSummary)
            detailRow("minScoreForNotification", "\(viewModel.minScoreForNotification)")
        }
        .photoCardStyle()
    }

    private var notificationDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("提醒质量")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if let rules = viewModel.notificationQualityRules {
                detailRow("daily max", "\(rules.dailyMaxNotifications)")
                detailRow("quiet hours", rules.quietHoursDescription)
                detailRow("mustShoot override", rules.allowMustShootOverride ? "on" : "off")
                detailRow("merge same location/category", rules.mergeNearbyNotifications ? "on" : "off")
            }

            if viewModel.skippedNotificationRecords.isEmpty {
                detailRow("recent skipped notifications", "0")
            } else {
                ForEach(viewModel.skippedNotificationRecords.prefix(5)) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.windowTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(record.reason)
                            .font(.caption)
                            .foregroundStyle(Color.photoMutedText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .photoCardStyle()
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label(viewModel.isLoading ? "刷新中" : "刷新远程事件数据", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)
            .disabled(viewModel.isLoading)

            Button {
                Task { await viewModel.clearCacheAndRefresh() }
            } label: {
                Label("清空缓存后重新拉取", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(viewModel.isLoading)

            Button {
                Task { await viewModel.reloadBundledJSON() }
            } label: {
                Label("重新加载 bundled JSON", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
            .disabled(viewModel.isLoading)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.photoMutedText)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func apiDiagnosticRow(_ result: APIDiagnosticResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(result.isSuccess ? Color.photoAccent : .red)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(result.endpointName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    if let statusCode = result.statusCode {
                        Text("\(statusCode)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.photoMutedText)
                    }
                }

                Text(result.path)
                    .font(.caption2)
                    .foregroundStyle(Color.photoMutedText)
                    .textSelection(.enabled)

                Text(result.summary)
                    .font(.caption)
                    .foregroundStyle(result.isSuccess ? Color.photoMutedText : .red.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func format(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "-"
    }
}
