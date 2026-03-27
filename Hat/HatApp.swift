//
//  MaeApp.swift
//  Hat
//
//  Created by Joao Simi on 19/02/26.
//

import SwiftUI
import KeyboardShortcuts
import UserNotifications
import CoreGraphics

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
        if !hasSeenWelcome {
            WelcomeWindowManager.shared.showWindow()
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        } else {
            // Open main window on launch
            MainWindowManager.shared.showWindow()
        }

        Task {
            await checkAndShowPermissionsIfNeeded()
        }

        UpdaterController.shared.checkForUpdatesInBackground()
    }

    private func checkAndShowPermissionsIfNeeded() async {
        let screenOK = CGPreflightScreenCaptureAccess()
        let notifSettings = await UNUserNotificationCenter.current().notificationSettings()
        let notifOK = notifSettings.authorizationStatus == .authorized

        if !screenOK || !notifOK {
            await MainActor.run {
                PermissionsWindowManager.shared.showWindow()
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct HatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AssistantViewModel.shared

    init() {
        KeychainManager.migrateIfNeeded()
        KeychainManager.migrateToAccessibleWhenUnlocked()

        KeyboardShortcuts.onKeyDown(for: .processClipboard) {
            Task {
                await AssistantViewModel.shared.processarIA()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .processScreen) {
            Task {
                await AssistantViewModel.shared.processarScreen()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .quickInput) {
            QuickInputWindowManager.shared.toggleWindow()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
        } label: {
            MenuBarIconView(isProcessing: viewModel.isProcessing)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Main Window Manager
class MainWindowManager {
    static let shared = MainWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let defaultWidth: CGFloat = 820
        let defaultHeight: CGFloat = 650

        let contentView = MainView()

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 600, height: 500)
        newWindow.title = "Hat"
        newWindow.center()

        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}

private struct MenuBarIconView: View {
    let isProcessing: Bool
    @State private var popScale: CGFloat = 1.0
    @State private var iconOpacity: Double = 1.0

    private var iconSide: CGFloat {
        max(13, NSStatusBar.system.thickness * 0.74)
    }

    var body: some View {
        Image(nsImage: statusBarImage)
            .interpolation(.high)
            .antialiased(true)
            .frame(width: iconSide, height: iconSide)
            .scaleEffect(popScale)
            .opacity(iconOpacity)
            .onAppear(perform: animateIconSwap)
            .onChange(of: isProcessing) { _, newValue in
                animateIconSwap()
                if newValue {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        iconOpacity = 0.7
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        iconOpacity = 1.0
                    }
                }
            }
    }

    private var statusBarImage: NSImage {
        let imageName = isProcessing ? "sunglasses-2-svgrepo-com" : "hat-svgrepo-com"
        let name = NSImage.Name(imageName)
        let image = (NSImage(named: name)?.copy() as? NSImage) ?? NSImage(size: NSSize(width: iconSide, height: iconSide))
        image.size = NSSize(width: iconSide, height: iconSide)
        image.isTemplate = true
        return image
    }

    private func animateIconSwap() {
        popScale = 0.85
        iconOpacity = 0.8

        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            popScale = 1.1
            iconOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                popScale = 1.0
            }
        }
    }
}

// MARK: - Permissions Window
class PermissionsWindowManager {
    static let shared = PermissionsWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 960)
        let width: CGFloat = min(520, screenRect.width * 0.45)
        let height: CGFloat = min(500, screenRect.height * 0.55)

        let contentView = PermissionsView(width: width, height: height)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}

// MARK: - Welcome Window
class WelcomeWindowManager {
    static let shared = WelcomeWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 960)
        let width = screenRect.width * 0.5
        let height = screenRect.height * 0.5

        let contentView = WelcomeView(width: width, height: height)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}

struct WelcomeView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Metrics.spacingLarge) {
                Image("pc")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 350)
                    .padding(.horizontal, 40)

                VStack(spacing: 8) {
                    Text("Bem-vindo ao Hat")
                        .font(Theme.Typography.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .maeStaggered(index: 1, baseDelay: 0.15)
                    Text("Seu assistente de IA na barra de menus")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .maeStaggered(index: 2, baseDelay: 0.15)
                }
            }
            .padding(.top, 50)
            .padding(.bottom, 20)

            VStack(spacing: Theme.Metrics.spacingXLarge) {
                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "arrow.up.to.line.compact",
                        title: "Sempre Pronto",
                        description: "Clique no icone na barra de menus no topo da tela (perto do relogio) para abrir o chat a qualquer momento."
                    )
                    .maeStaggered(index: 3, baseDelay: 0.10)

                    FeatureRow(
                        icon: "macwindow.badge.plus",
                        title: "Analise de Tela Inteligente",
                        description: "Pressione Cmd+Shift+Z para capturar sua tela e receber ajuda contextual automatica."
                    )
                    .maeStaggered(index: 4, baseDelay: 0.10)

                    FeatureRow(
                        icon: "doc.on.clipboard",
                        title: "Analise de Area de Transferencia",
                        description: "Pressione Cmd+Shift+X para que a IA analise imediatamente o que voce copiou."
                    )
                    .maeStaggered(index: 5, baseDelay: 0.10)
                }
                .padding(.horizontal, 40)

                Spacer()

                MaeActionButton(label: "Comecar a Usar", style: .accent) {
                    WelcomeWindowManager.shared.closeWindow()
                }
                .maeStaggered(index: 6, baseDelay: 0.10)

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.35))
                    .padding(.bottom, 20)
            }
            .padding(.top, 10)
            .frame(maxHeight: .infinity)
        }
        .background(MaePageBackground())
        .ignoresSafeArea()
        .frame(width: width, height: height)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Colors.accentPrimary)
                .frame(width: 32, height: 32)
                .background(Theme.Colors.accentPrimary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(description)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Permissions Views

struct PermissionRowView: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onGrant: () -> Void
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(isGranted ? Theme.Colors.success : Theme.Colors.accentPrimary)
                .frame(width: 32, height: 32)
                .background(isGranted ? Theme.Colors.success.opacity(0.08) : Theme.Colors.accentPrimary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(description)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.success)
                    .transition(.maeScaleFade)
            } else {
                Button(action: onGrant) {
                    Text("Permitir")
                        .font(Theme.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                        .fill(Theme.Colors.accentPrimary)
                )
                .maePressEffect()
                .transition(.maeScaleFade)
            }
        }
        .padding(Theme.Metrics.spacingLarge)
        .maeCardStyle()
        .maeStaggered(index: index, baseDelay: 0.12)
    }
}

@MainActor
struct PermissionsView: View {
    let width: CGFloat
    let height: CGFloat

    @State private var screenRecordingGranted: Bool = CGPreflightScreenCaptureAccess()
    @State private var notificationsGranted: Bool = false

    private var allGranted: Bool { screenRecordingGranted && notificationsGranted }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentPrimary.opacity(0.06))
                        .frame(width: 64, height: 64)
                    Image(systemName: allGranted ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Theme.Colors.accentPrimary)
                        .symbolEffect(.bounce, value: allGranted)
                }
                .maeStaggered(index: 0, baseDelay: 0.12)

                Text("Permissoes Necessarias")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .maeStaggered(index: 1, baseDelay: 0.12)

                Text("O Hat precisa das seguintes permissoes para funcionar corretamente.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .maeStaggered(index: 2, baseDelay: 0.12)

                HStack(spacing: 6) {
                    let grantedCount = (screenRecordingGranted ? 1 : 0) + (notificationsGranted ? 1 : 0)
                    Text("\(grantedCount)/2 permissoes")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(allGranted ? Theme.Colors.success : Theme.Colors.textMuted)
                    if allGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.success)
                            .transition(.maeScaleFade)
                    }
                }
                .maeStaggered(index: 2, baseDelay: 0.12)
                .animation(Theme.Animation.smooth, value: screenRecordingGranted)
                .animation(Theme.Animation.smooth, value: notificationsGranted)
            }
            .padding(.top, 36)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                PermissionRowView(
                    icon: "rectangle.dashed.badge.record",
                    title: "Gravacao de Tela",
                    description: "Necessaria para o atalho Cmd+Shift+Z capturar a tela e enviar ao modelo de IA para analise.",
                    isGranted: screenRecordingGranted,
                    onGrant: requestScreenRecording,
                    index: 3
                )

                PermissionRowView(
                    icon: "bell.badge",
                    title: "Notificacoes",
                    description: "Usada para exibir as respostas da IA mesmo quando o app nao esta em foco.",
                    isGranted: notificationsGranted,
                    onGrant: requestNotifications,
                    index: 4
                )
            }
            .padding(.horizontal, 24)
            .animation(Theme.Animation.smooth, value: screenRecordingGranted)
            .animation(Theme.Animation.smooth, value: notificationsGranted)

            Spacer()

            VStack(spacing: 12) {
                if !allGranted {
                    Button(action: recheckPermissions) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Ja Concedi")
                                .font(Theme.Typography.bodySmall)
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .maeStaggered(index: 5, baseDelay: 0.12)
                }

                Button(action: {
                    PermissionsWindowManager.shared.closeWindow()
                }) {
                    Text(allGranted ? "Continuar" : "Continuar mesmo assim")
                        .font(Theme.Typography.bodyBold)
                        .foregroundStyle(allGranted ? .white : Theme.Colors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 32)
                        .background(
                            allGranted
                                ? RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                                    .fill(Theme.Colors.accentPrimary)
                                : nil
                        )
                }
                .buttonStyle(.plain)
                .maePressEffect()
                .maeStaggered(index: 6, baseDelay: 0.12)
                .animation(Theme.Animation.smooth, value: allGranted)
            }
            .padding(.bottom, 30)
        }
        .background(MaePageBackground())
        .ignoresSafeArea()
        .frame(width: width, height: height)
        .task {
            await refreshNotificationStatus()
        }
    }

    private func requestScreenRecording() {
        let granted = CGRequestScreenCaptureAccess()
        if granted {
            withAnimation(Theme.Animation.smooth) {
                screenRecordingGranted = true
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func requestNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
                withAnimation(Theme.Animation.smooth) {
                    notificationsGranted = granted
                }
            } else {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func recheckPermissions() {
        withAnimation(Theme.Animation.smooth) {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
        Task {
            await refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        withAnimation(Theme.Animation.smooth) {
            notificationsGranted = settings.authorizationStatus == .authorized
        }
    }
}
