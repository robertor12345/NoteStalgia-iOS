import SwiftUI
import PhotosUI

// MARK: - Camera path — confirm photo, then straight to session

/// "Opening photo…" while a library photo loads, or a soft failure line — shared by the photo
/// pickers so a slow or broken import is never silent.
struct PhotoLoadStatusLine: View {
    var isLoading: Bool
    var error: String?

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 10) {
                    BreathingCalmProgressView(diameter: 26, pace: .brisk)
                    Text("Opening photo…")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                .transition(.opacity)
                .accessibilityElement(children: .combine)
            } else if let error, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.nebulaSalmon)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(CalmMotion.subtle, value: isLoading)
    }
}

struct CapturePhotoView: View {
    @ObservedObject var state: SessionPOCState
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isLoadingPhoto = false
    @State private var photoLoadError: String?

    var body: some View {
        ScreenFadeIn {
            GeometryReader { geo in
                CenteredScrollScreen(onBack: {
                    state.capturedImage = nil
                    photoItem = nil
                    state.phase = .entryMode
                }, onLogout: state.isSignedIn ? { state.signOutSupervisor() } : nil) {
                    if state.capturedImage != nil {
                        photoConfirmationContent(viewportHeight: geo.size.height)
                    } else {
                        photoPickContent
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $state.capturedImage)
                .ignoresSafeArea()
        }
    }

    // MARK: Pick / capture

    private var photoPickContent: some View {
        VStack(spacing: 20) {
            FadeInLine(
                text: "Choose one from your library or take something new — then we’ll build the session around it.",
                delay: 0.06
            )

            BrandCard {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(BrandTheme.goldDeep)
                    Text("Add a photo to move on")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                OrbPickerLabel(title: "Choose from library", systemImage: "photo.stack")
            }
            .accessibilityIdentifier("capture.chooseLibrary")
            .buttonStyle(ChimingPlainButtonStyle())
            .onChange(of: photoItem) { _, new in
                guard let new else { return }
                isLoadingPhoto = true
                photoLoadError = nil
                // Library photos can be 12 MP+: load and decode off the main thread so the
                // screen keeps animating, and say so while it happens.
                Task.detached(priority: .userInitiated) {
                    let data = try? await new.loadTransferable(type: Data.self)
                    let image = data.flatMap { UIImage.decodedThumbnail(from: $0, maxDimension: 1200) }
                    await MainActor.run {
                        isLoadingPhoto = false
                        if let image {
                            state.capturedImage = image
                        } else {
                            photoLoadError = "That photo couldn’t be opened. Try another one."
                        }
                    }
                }
            }

            PhotoLoadStatusLine(isLoading: isLoadingPhoto, error: photoLoadError)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    OrbPickerLabel(title: "Take a picture", systemImage: "camera.fill")
                }
                .accessibilityIdentifier("capture.takePicture")
                .buttonStyle(ChimingPlainButtonStyle())
            }

        }
        .padding(24)
    }

    // MARK: Confirm before session

    private func photoConfirmationContent(viewportHeight: CGFloat) -> some View {
        VStack(spacing: 22) {
            if let img = state.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: BrandLayout.photoPreviewMaxHeight(for: viewportHeight))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BrandTheme.gold.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: BrandTheme.brown.opacity(0.12), radius: 16, y: 6)
            }

            PrimaryButton(title: "Start session") {
                state.beginSession()
                state.phase = .immersive
            }
            .accessibilityIdentifier("capture.startSession")
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                SecondaryButton(title: "Choose another photo") {
                    state.capturedImage = nil
                    photoItem = nil
                }
                .accessibilityIdentifier("capture.chooseAnother")
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    SecondaryButton(title: "Take again") {
                        state.capturedImage = nil
                        showCamera = true
                    }
                    .accessibilityIdentifier("capture.takeAgain")
                }
            }
            .padding(.horizontal, 4)

        }
        .padding(24)
    }
}

// MARK: - Camera bridge

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let ui = info[.originalImage] as? UIImage {
                parent.image = ui.downscaledForDisplay()
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
