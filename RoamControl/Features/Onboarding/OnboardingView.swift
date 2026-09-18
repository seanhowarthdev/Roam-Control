import SwiftUI

struct OnboardingView: View {
    @Environment(\.locale) private var locale
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
                    Text(AppLocalization.text("ROAM CONTROL", locale: locale))
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
                            .accessibilityLabel(AppLocalization.text("Close introduction", locale: locale))
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
                    .accessibilityLabel(AppLocalization.text("Page \(selectedPage + 1) of \(pages.count)", locale: locale))

                    Button {
                        advance()
                    } label: {
                        HStack {
                            Text(AppLocalization.text(finalButtonTitle, locale: locale))
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
    @Environment(\.locale) private var locale
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let page: OnboardingPage

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer(minLength: 20)

                    Group {
                        if page.symbol == "location.viewfinder" {
                            Image("CatGoLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: dynamicTypeSize.isAccessibilitySize ? 84 : 116,
                                    height: dynamicTypeSize.isAccessibilitySize ? 84 : 116
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        } else {
                            Image(systemName: page.symbol)
                        }
                    }
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
                        Text(AppLocalization.text(page.title, locale: locale))
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(AppLocalization.text(page.message, locale: locale))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .accessibilityElement(children: .combine)
            }
        }
    }

}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String
    let colors: [Color]

    init(
        symbol: String,
        title: String,
        message: String,
        colors: [Color]
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.colors = colors
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
            message: "The pairing record is generated or checked on this iPhone, then stored only in its Keychain. Roam Control does not upload it.",
            colors: [.indigo, .purple]
        )
    ]
}

#Preview {
    OnboardingView()
        .environment(AppModel())
}
