import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0

    let isReplay: Bool
    private let pages = OnboardingPage.pages

    init(isReplay: Bool = false) {
        self.isReplay = isReplay
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.16),
                    Color.cyan.opacity(0.07),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("ROAM CONTROL")
                        .font(.caption.weight(.bold))
                        .tracking(2.2)
                        .foregroundStyle(.secondary)

                    if isReplay {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close introduction")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 22) {
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedPage ? Color.blue : Color.secondary.opacity(0.25))
                                .frame(width: index == selectedPage ? 24 : 8, height: 8)
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.3),
                                    value: selectedPage
                                )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(selectedPage + 1) of \(pages.count)")

                    Button {
                        advance()
                    } label: {
                        HStack {
                            Text(finalButtonTitle)
                            Image(systemName: finalButtonSymbol)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var isLastPage: Bool {
        selectedPage == pages.count - 1
    }

    private func advance() {
        if isLastPage {
            if isReplay {
                dismiss()
            } else {
                appModel.completeOnboarding()
            }
        } else {
            if reduceMotion {
                selectedPage += 1
            } else {
                withAnimation {
                    selectedPage += 1
                }
            }
        }
    }

    private var finalButtonTitle: String {
        if !isLastPage { return "Continue" }
        return isReplay ? "Done" : "Set Up This iPhone"
    }

    private var finalButtonSymbol: String {
        if !isLastPage { return "arrow.right" }
        return isReplay ? "checkmark" : "iphone.and.arrow.forward"
    }
}

private struct OnboardingPageView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let page: OnboardingPage

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer(minLength: 20)

                    Image(systemName: page.symbol)
                        .font(.system(
                            size: dynamicTypeSize.isAccessibilitySize ? 46 : 64,
                            weight: .semibold
                        ))
                        .foregroundStyle(.white)
                        .frame(
                            width: dynamicTypeSize.isAccessibilitySize ? 96 : 132,
                            height: dynamicTypeSize.isAccessibilitySize ? 96 : 132
                        )
                        .background(
                            LinearGradient(
                                colors: page.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(
                                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 26 : 34,
                                style: .continuous
                            )
                        )
                        .shadow(color: page.colors[0].opacity(0.28), radius: 24, y: 14)
                        .accessibilityHidden(true)

                    VStack(spacing: 14) {
                        Text(page.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(page.message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)

                    if page.showsUsageStatisticsControl {
                        usageStatisticsCard
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var usageStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                "Share Anonymous Usage Statistics",
                isOn: Binding(
                    get: { appModel.sharesAnonymousUsageStatistics },
                    set: appModel.setSharesAnonymousUsageStatistics
                )
            )
            .font(.headline)

            Label {
                Text("Off by default. Never includes locations, searches, routes, pairing data or personal information.")
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.green)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String
    let colors: [Color]
    let showsUsageStatisticsControl: Bool

    init(
        symbol: String,
        title: String,
        message: String,
        colors: [Color],
        showsUsageStatisticsControl: Bool = false
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.colors = colors
        self.showsUsageStatisticsControl = showsUsageStatisticsControl
    }

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "location.viewfinder",
            title: "Welcome to Roam Control",
            message: "Choose where your iPhone should appear, from one simple map.",
            colors: [.blue, .cyan]
        ),
        OnboardingPage(
            symbol: "map.fill",
            title: "Pick any place",
            message: "Search for a destination or tap the map, then save it as your target.",
            colors: [.indigo, .blue]
        ),
        OnboardingPage(
            symbol: "iphone.and.arrow.forward",
            title: "Pair this iPhone once",
            message: "Roam Control needs one private pairing before it can control location. We'll guide you through it next.",
            colors: [.green, .teal]
        ),
        OnboardingPage(
            symbol: "hand.raised.fill",
            title: "Private by design",
            message: "Choose whether to help improve Roam Control with anonymous activity counts. Sharing starts only if you switch it on and can be changed later in Settings.",
            colors: [.indigo, .purple],
            showsUsageStatisticsControl: true
        )
    ]
}

#Preview {
    OnboardingView()
        .environment(AppModel())
}
