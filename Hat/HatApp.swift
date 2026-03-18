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

// MARK: - App Delegate para gerenciar notificações
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configura o delegado para capturar notificações em primeiro plano
        UNUserNotificationCenter.current().delegate = self

        // Verifica primeiro acesso para mostrar a janela de boas vindas
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
        if !hasSeenWelcome {
            WelcomeWindowManager.shared.showWindow()
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }

        // Verifica permissões a cada inicialização; abre tela de permissões se alguma estiver faltando
        Task {
            await checkAndShowPermissionsIfNeeded()
        }

        // Verifica atualizações silenciosamente
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
    
    // Esta função permite que a notificação apareça mesmo que o app esteja focado
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Define que queremos mostrar o banner e tocar o som mesmo com o app aberto
        completionHandler([.banner, .sound])
    }
}

@main
struct HatApp: App {
    // Adaptador para usar o AppDelegate em SwiftUI
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AssistantViewModel.shared

    init() {
        // Migra chave de API única para chaves por provedor (one-time)
        KeychainManager.migrateIfNeeded()

        // Re-salva chaves com kSecAttrAccessibleWhenUnlocked para evitar
        // prompt de permissão do Keychain a cada atualização do app
        KeychainManager.migrateToAccessibleWhenUnlocked()

        // Registramos o listener global para o atalho quando o app inicia
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
            ContentView()
        } label: {
            MenuBarIconView(isProcessing: viewModel.isProcessing)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIconView: View {
    let isProcessing: Bool
    @State private var popScale: CGFloat = 1.0
    @State private var iconOpacity: Double = 1.0
    
    private var iconSide: CGFloat {
        // Usa a espessura real da menubar (em pontos) para escalar em qualquer resolução.
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
            .onChange(of: isProcessing) { _ in
                animateIconSwap()
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
        popScale = 0.82
        iconOpacity = 0.75
        
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5, blendDuration: 0.05)) {
            popScale = 1.18
            iconOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78, blendDuration: 0.05)) {
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
            // Header
            VStack(spacing: Theme.Metrics.spacingLarge) {
                Image("pc")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 350)
                    .padding(.horizontal, 40)

                VStack(spacing: 6) {
                    Text("Bem-vindo ao Hat")
                        .font(Theme.Typography.largeTitle)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .maeStaggered(index: 1, baseDelay: 0.15)
                    Text("Seu assistente de IA na barra de menus")
                        .font(Theme.Typography.bodySmall)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .maeStaggered(index: 2, baseDelay: 0.15)
                }
            }
            .padding(.top, 50)
            .padding(.bottom, 20)

            // Content
            VStack(spacing: Theme.Metrics.spacingXLarge) {

                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "arrow.up.to.line.compact",
                        title: "Sempre Pronto",
                        description: "Clique no ícone na barra de menus no topo da tela (perto do relógio) para abrir o chat a qualquer momento."
                    )
                    .maeStaggered(index: 3, baseDelay: 0.10)

                    FeatureRow(
                        icon: "macwindow.badge.plus",
                        title: "Análise de Tela Inteligente",
                        description: "Pressione ⌘ + ⇧ + Z para capturar sua tela e receber ajuda contextual automática."
                    )
                    .maeStaggered(index: 4, baseDelay: 0.10)

                    FeatureRow(
                        icon: "doc.on.clipboard",
                        title: "Análise de Área de Transferência",
                        description: "Pressione ⌘ + ⇧ + X para que a IA analise imediatamente o que você copiou."
                    )
                    .maeStaggered(index: 5, baseDelay: 0.10)
                }
                .padding(.horizontal, 40)

                Spacer()

                MaeActionButton(label: "Começar a Usar") {
                    WelcomeWindowManager.shared.closeWindow()
                }
                .maeStaggered(index: 6, baseDelay: 0.10)
                .padding(.bottom, 30)
            }
            .padding(.top, 10)
            .frame(maxHeight: .infinity)
        }
        .background(MaePageBackground(showGlow: true))
        .edgesIgnoringSafeArea(.all)
        .frame(width: width, height: height)
        .preferredColorScheme(.dark)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.gradientStart, Theme.Colors.gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .background(Theme.Colors.accentSubtle.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(description)
                    .font(Theme.Typography.bodySmall)
                    .foregroundColor(Theme.Colors.textSecondary)
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
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(
                    isGranted
                        ? AnyShapeStyle(Theme.Colors.success)
                        : AnyShapeStyle(LinearGradient(
                            colors: [Theme.Colors.gradientStart, Theme.Colors.gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .background(isGranted ? Theme.Colors.success.opacity(0.12) : Theme.Colors.accentSubtle.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(description)
                    .font(Theme.Typography.bodySmall)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.success)
                    .transition(.maeScaleFade)
            } else {
                Button(action: onGrant) {
                    Text("Permitir")
                        .font(Theme.Typography.bodyBold)
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                        .fill(Theme.Colors.accent.opacity(0.9))
                )
                .maeGlowHover()
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
            // Header
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentBlue.opacity(0.08))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.shield")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Colors.gradientStart, Theme.Colors.gradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .maeStaggered(index: 0, baseDelay: 0.12)

                Text("Permissões Necessárias")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .maeStaggered(index: 1, baseDelay: 0.12)

                Text("O Hat precisa das seguintes permissões para funcionar corretamente.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .maeStaggered(index: 2, baseDelay: 0.12)
            }
            .padding(.top, 36)
            .padding(.bottom, 24)

            // Linhas de permissão
            VStack(spacing: 12) {
                PermissionRowView(
                    icon: "rectangle.dashed.badge.record",
                    title: "Gravação de Tela",
                    description: "Necessária para o atalho ⌘+⇧+Z capturar a tela e enviar ao modelo de IA para análise.",
                    isGranted: screenRecordingGranted,
                    onGrant: requestScreenRecording,
                    index: 3
                )

                PermissionRowView(
                    icon: "bell.badge",
                    title: "Notificações",
                    description: "Usada para exibir as respostas da IA mesmo quando o app não está em foco.",
                    isGranted: notificationsGranted,
                    onGrant: requestNotifications,
                    index: 4
                )
            }
            .padding(.horizontal, 24)
            .animation(Theme.Animation.smooth, value: screenRecordingGranted)
            .animation(Theme.Animation.smooth, value: notificationsGranted)

            Spacer()

            // Rodapé
            VStack(spacing: 12) {
                if !allGranted {
                    Button(action: recheckPermissions) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Já Concedi")
                                .font(Theme.Typography.bodySmall)
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .maeStaggered(index: 5, baseDelay: 0.12)
                }

                Button(action: {
                    PermissionsWindowManager.shared.closeWindow()
                }) {
                    Text(allGranted ? "Continuar" : "Continuar mesmo assim")
                        .font(Theme.Typography.bodyBold)
                        .foregroundColor(allGranted ? .black : Theme.Colors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                        .fill(allGranted ? Theme.Colors.accent.opacity(0.85) : Color.white.opacity(0.10))
                )
                .maeGlowHover()
                .maePressEffect()
                .maeStaggered(index: 6, baseDelay: 0.12)
                .animation(Theme.Animation.smooth, value: allGranted)
            }
            .padding(.bottom, 30)
        }
        .background(MaePageBackground(showGlow: true))
        .edgesIgnoringSafeArea(.all)
        .frame(width: width, height: height)
        .preferredColorScheme(.dark)
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
