import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct LCAppIconDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct LCNativeAppItem: View {
    @ObservedObject var model: LCAppModel
    let isGrid: Bool
    let delegate: LCAppBannerDelegate
    let onLaunch: (LCAppModel, Bool?) -> Void
    let onError: (String) -> Void

    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    @State private var showingUninstallConfirmation = false
    @State private var iconExportDocument: LCAppIconDocument?
    @State private var isExportingIcon = false
    @State private var iconExportName = "App Icon"

    private var appIcon: UIImage {
        model.appInfo.iconIsDarkIcon(darkModeIcon) ?? UIImage()
    }

    var body: some View {
        Button {
            onLaunch(model, nil)
        } label: {
            Group {
                if isGrid {
                    gridContent
                } else {
                    listContent
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.displayName), \(model.version)")
        .contextMenu {
            if model.uiContainers.count > 1 {
                Menu("Containers") {
                    ForEach(model.uiContainers, id: \.folderName) { container in
                        Button {
                            model.uiSelectedContainer = container
                        } label: {
                            if container.folderName == model.uiSelectedContainer?.folderName {
                                Label(container.name, systemImage: "checkmark")
                            } else {
                                Text(container.name)
                            }
                        }
                    }
                }
            }

            if !model.uiIsShared, model.uiSelectedContainer != nil {
                Button {
                    openDataFolder()
                } label: {
                    Label("lc.appBanner.openDataFolder".loc, systemImage: "folder")
                }
            }

            if #available(iOS 16.0, *) {
                Button {
                    onLaunch(model, !model.shouldLaunchInMultitaskMode)
                } label: {
                    Label(
                        model.shouldLaunchInMultitaskMode ? "lc.appBanner.run".loc : "lc.appBanner.multitask".loc,
                        systemImage: model.shouldLaunchInMultitaskMode ? "play.fill" : "macwindow.badge.plus"
                    )
                }
                .disabled(model.isAppRunning)
            }

            Menu("lc.appBanner.addToHomeScreen".loc) {
                Button {
                    copyLaunchURL()
                } label: {
                    Label("lc.appBanner.copyLaunchUrl".loc, systemImage: "link")
                }

                Button {
                    Task { await prepareIconExport() }
                } label: {
                    Label("lc.appBanner.saveAppIcon".loc, systemImage: "square.and.arrow.down")
                }

                Button {
                    createAppClip()
                } label: {
                    Label("lc.appBanner.createAppClip".loc, systemImage: "appclip")
                }
            }

            Button {
                delegate.openNavigationView(view: AnyView(LCAppSettingsView(model: model)))
            } label: {
                Label("lc.tabView.settings".loc, systemImage: "gear")
            }

            if !model.uiIsShared {
                Button(role: .destructive) {
                    showingUninstallConfirmation = true
                } label: {
                    Label("lc.appBanner.uninstall".loc, systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "lc.appBanner.confirmUninstallTitle".loc,
            isPresented: $showingUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("lc.appBanner.uninstall".loc, role: .destructive) {
                uninstallApp(deleteData: false)
            }

            if !model.appInfo.containers.isEmpty {
                Button("Uninstall & Delete Data", role: .destructive) {
                    uninstallApp(deleteData: true)
                }
            }

            Button("lc.common.cancel".loc, role: .cancel) {}
        } message: {
            Text("lc.appBanner.confirmUninstallMsg %@".localizeWithFormat(model.displayName))
        }
        .fileExporter(
            isPresented: $isExportingIcon,
            document: iconExportDocument,
            contentType: .png,
            defaultFilename: iconExportName
        ) { result in
            if case .failure(let error) = result {
                onError(error.localizedDescription)
            }
            iconExportDocument = nil
        }
    }

    private var listContent: some View {
        HStack(spacing: 14) {
            iconView(size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(model.version)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 0.5)
                .padding(.leading, 70)
        }
    }

    private var gridContent: some View {
        VStack(spacing: 7) {
            iconView(size: 66)

            Text(model.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            Text(model.version)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func iconView(size: CGFloat) -> some View {
        Image(uiImage: appIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }

    private func openDataFolder() {
        guard let folderName = model.uiSelectedContainer?.folderName,
              let url = URL(string: "shareddocuments://\(LCPath.dataPath.path)/\(folderName)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func copyLaunchURL() {
        guard let relativeBundlePath = model.appInfo.relativeBundlePath else {
            return
        }

        if let folderName = model.uiSelectedContainer?.folderName {
            UIPasteboard.general.string = "livecontainer://livecontainer-launch?bundle-name=\(relativeBundlePath)&container-folder-name=\(folderName)"
        } else {
            UIPasteboard.general.string = "livecontainer://livecontainer-launch?bundle-name=\(relativeBundlePath)"
        }
    }

    private func prepareIconExport() async {
        guard let style = await delegate.promptForGeneratedIconStyle() else {
            return
        }

        guard let image = model.appInfo.generateLiveContainerWrappedIcon(with: style),
              let data = image.pngData() else {
            onError("Unable to generate the app icon.")
            return
        }

        iconExportName = model.displayName.replacingOccurrences(of: "/", with: "_") + " Icon"
        iconExportDocument = LCAppIconDocument(data: data)
        isExportingIcon = true
    }

    private func createAppClip() {
        Task {
            guard let style = await delegate.promptForGeneratedIconStyle() else {
                return
            }

            do {
                guard let profile = model.appInfo.generateWebClipConfig(
                    withContainerId: model.uiSelectedContainer?.folderName,
                    iconStyle: style
                ) else {
                    throw CocoaError(.propertyListWriteInvalid)
                }

                let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
                delegate.installMdm(data: data)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    private func uninstallApp(deleteData: Bool) {
        Task {
            do {
                guard let bundlePath = model.appInfo.bundlePath() else {
                    throw CocoaError(.fileNoSuchFile)
                }

                try FileManager.default.removeItem(atPath: bundlePath)
                delegate.removeApp(app: model)

                if deleteData {
                    for container in model.appInfo.containers {
                        let dataUUID = container.folderName
                        try FileManager.default.removeItem(at: LCPath.dataPath.appendingPathComponent(dataUUID))
                        LCUtils.removeAppKeychain(dataUUID: dataUUID)
                        DataManager.shared.model.appDataFolderNames.removeAll { $0 == dataUUID }
                    }
                }
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}
