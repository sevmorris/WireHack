import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 20) {
            header

            VStack(alignment: .leading, spacing: 16) {
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste or drop URL")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("https://www.youtube.com/watch?v=...", text: $viewModel.url)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.95))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                        .disabled(viewModel.isDownloading)
                }

                // Format Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    FormatSegmentedControl(
                        selection: $viewModel.selectedFormat,
                        isDisabled: viewModel.isDownloading
                    )
                }

                // Browser cookies — unlocks age-restricted / members-only content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Access")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use browser cookies", isOn: $viewModel.cookiesEnabled)
                            .toggleStyle(.checkbox)
                            .foregroundStyle(.white)
                            .disabled(viewModel.isDownloading)

                        if viewModel.cookiesEnabled {
                            HStack {
                                Text("Browser")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                                Picker("Browser", selection: $viewModel.cookiesBrowser) {
                                    ForEach(CookiesBrowser.allCases) { browser in
                                        Text(browser.displayName).tag(browser)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .disabled(viewModel.isDownloading)
                            }
                        }
                    }
                    .padding(8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Numbering
                VStack(alignment: .leading, spacing: 8) {
                    Text("Numbering")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    HStack {
                        Toggle("Auto-number", isOn: $viewModel.numberingEnabled)
                            .toggleStyle(.checkbox)
                            .foregroundStyle(.white)
                            .disabled(viewModel.isDownloading)

                        Spacer()

                        Button("Reset") {
                            viewModel.currentNumber = 1
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.white)
                        .disabled(viewModel.isDownloading || !viewModel.numberingEnabled || viewModel.currentNumber == 1)
                        .opacity(viewModel.numberingEnabled ? 1 : 0.5)

                        Stepper(value: $viewModel.currentNumber, in: 1...9999) {
                            Text(String(format: "%02d", viewModel.currentNumber))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(minWidth: 28, alignment: .trailing)
                        }
                        .disabled(viewModel.isDownloading || !viewModel.numberingEnabled)
                        .opacity(viewModel.numberingEnabled ? 1 : 0.5)
                    }
                    .padding(8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Manifest
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manifest")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    HStack {
                        Toggle("Save clip list", isOn: $viewModel.manifestEnabled)
                            .toggleStyle(.checkbox)
                            .foregroundStyle(.white)
                            .disabled(viewModel.isDownloading)
                        Spacer()
                    }
                    .padding(8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Notes (only when manifest is on)
                if viewModel.manifestEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        TextField("e.g. :30 to :12", text: $viewModel.notes, axis: .vertical)
                            .lineLimit(1...4)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.white.opacity(0.95))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.25), lineWidth: 1)
                            )
                            .disabled(viewModel.isDownloading)
                    }
                }

                // Output Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Destination")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    HStack {
                        Text(viewModel.outputDirectory?.lastPathComponent ?? "Choose folder...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose...") {
                            viewModel.selectOutputDirectory()
                        }
                        .disabled(viewModel.isDownloading)
                    }
                    .padding(8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Button(action: viewModel.primaryButtonTap) {
                HStack {
                    if viewModel.isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(viewModel.primaryButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isDownloading ? .red : .brandOrange)
            .disabled(!viewModel.canTriggerPrimary)
            .keyboardShortcut(.return, modifiers: [])

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            } else {
                Text(viewModel.status)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(
            LinearGradient(
                colors: [.brandBlueLight, .brandBlueDark],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .dropDestination(for: URL.self) { items, _ in
            guard let dropped = items.first else { return false }
            viewModel.acceptIncomingURL(dropped.absoluteString, replaceExisting: true)
            return true
        }
        .task {
            // One-shot clipboard auto-fill: if the field is empty and the
            // pasteboard holds a plausible URL, prefill it as a convenience.
            if viewModel.url.isEmpty,
               let s = NSPasteboard.general.string(forType: .string) {
                viewModel.acceptIncomingURL(s, replaceExisting: false)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.brandOrange.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.down")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("WireHack")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("yt-dlp wrapper")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }
}

extension Color {
    /// Lighter blue from the app icon's top edge.
    static let brandBlueLight = Color(red: 36 / 255, green: 96 / 255, blue: 146 / 255)
    /// Darker blue from the app icon's bottom edge.
    static let brandBlueDark = Color(red: 15 / 255, green: 51 / 255, blue: 88 / 255)
    /// The orange of the icon's arrow.
    static let brandOrange = Color(red: 216 / 255, green: 116 / 255, blue: 50 / 255)
}

private struct FormatSegmentedControl: View {
    @Binding var selection: DownloadFormat
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DownloadFormat.allCases) { format in
                segment(for: format)
            }
        }
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.5 : 1)
        .allowsHitTesting(!isDisabled)
    }

    private func segment(for format: DownloadFormat) -> some View {
        let isSelected = selection == format
        return Button {
            selection = format
        } label: {
            Text(format.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.brandOrange : .clear)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel())
}
