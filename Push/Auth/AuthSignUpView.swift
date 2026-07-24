// Push/Auth/AuthSignUpView.swift
import PhotosUI
import SwiftUI
import UIKit

/// Sign-up step 1 — lab "Make it you." profile layout.
/// Name + handle are required; photo is optional and uploads after live prepare.
struct AuthSignUpProfileView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Make it you.",
                subtitle: "This is how friends will spot you on the map."
            )
            photoPicker
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
            fields.padding(.top, 30)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            if let photoError = model.photoErrorMessage {
                Text(photoError)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            Spacer(minLength: 28)
            OnboardingCTAButton(title: "Continue") {
                model.continueSignUpProfile()
            }
            .disabled(!model.canContinueSignUpProfile)
            .opacity(model.canContinueSignUpProfile ? 1 : 0.5)
            .animation(OnboardingLabMotion.fast, value: model.canContinueSignUpProfile)
            OnboardingAuthSwitchLink(
                prompt: "Already have an account?",
                action: "Sign in"
            ) { model.showSignIn() }
            .padding(.top, 16)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, 26)
        .onChange(of: photoPickerItem) { item in
            guard let item else { return }
            Task { await loadPickedPhoto(item) }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                photoContent
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(OnboardingLabColor.ctaLabel)
                    .frame(width: 34, height: 34)
                    .background(OnboardingLabColor.ctaBottom, in: Circle())
            }
            .frame(width: 118, height: 118)
        }
        .buttonStyle(PushPressStyle())
        .disabled(model.isPhotoBusy || model.isBusy)
        .accessibilityLabel(model.hasPendingProfilePhoto ? "Change profile photo" : "Add profile photo")
    }

    @ViewBuilder
    private var photoContent: some View {
        if model.isPhotoBusy {
            ProgressView()
                .frame(width: 118, height: 118)
                .background(OnboardingLabColor.fieldFill, in: Circle())
        } else if let jpeg = model.pendingProfilePhotoJPEG,
                  let image = UIImage(data: jpeg) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 118, height: 118)
                .clipShape(Circle())
                .overlay(Circle().stroke(OnboardingLabColor.sunbeam, lineWidth: 3))
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: 30))
                .foregroundStyle(OnboardingLabColor.walnut)
                .frame(width: 118, height: 118)
                .background(OnboardingLabColor.fieldFill, in: Circle())
                .overlay(Circle().stroke(OnboardingLabColor.walnut.opacity(0.16), lineWidth: 2))
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            labeledField(label: "Name") {
                TextField("First name", text: $model.displayName)
                    .font(OnboardingLabFont.rounded(18, .semibold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            labeledField(label: "Handle") {
                HStack(spacing: 2) {
                    Text("@")
                        .font(OnboardingLabFont.rounded(18, .bold))
                        .foregroundStyle(OnboardingLabColor.textTertiary)
                    TextField("yourname", text: handleBinding)
                        .font(OnboardingLabFont.rounded(18, .semibold))
                        .foregroundStyle(OnboardingLabColor.espresso)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                }
            }
        }
    }

    private var handleBinding: Binding<String> {
        Binding(
            get: { model.handle },
            set: { model.setHandle($0) }
        )
    }

    private func labeledField<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(OnboardingLabFont.text(12, .bold))
                .kerning(0.5)
                .foregroundStyle(OnboardingLabColor.textTertiary)
                .padding(.leading, 6)
            content()
                .padding(.horizontal, 18)
                .frame(height: OnboardingLabMetric.fieldHeight)
                .background(
                    OnboardingLabColor.fieldFill,
                    in: RoundedRectangle(cornerRadius: OnboardingLabMetric.fieldCornerRadius, style: .continuous)
                )
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let raw = try await item.loadTransferable(type: Data.self) else {
                model.photoErrorMessage = "Couldn't read that photo. Try another one."
                photoPickerItem = nil
                return
            }
            model.applyPickedProfilePhoto(rawData: raw)
        } catch {
            model.photoErrorMessage = "Couldn't read that photo. Try another one."
        }
        photoPickerItem = nil
    }
}

/// Sign-up step 2 — email + password, then create account via Supabase Auth.
struct AuthSignUpCredentialsView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeader(
                    title: "Create your account",
                    subtitle: "Use an email you’ll check — we’ll only write when it matters."
                )
                if model.hasPendingProfilePhoto || !model.trimmedDisplayName.isEmpty {
                    identitySummary.padding(.top, 18)
                }
                fields.padding(.top, 26)
                if let error = model.errorMessage {
                    Text(error)
                        .font(OnboardingLabFont.text(14, .medium))
                        .foregroundStyle(.red)
                        .padding(.top, 10)
                }
                OnboardingCTAButton(title: model.isBusy ? "Creating…" : "Create account") {
                    Task { await model.submitSignUp() }
                }
                .disabled(!model.canSubmitSignUp)
                .opacity(model.canSubmitSignUp ? 1 : 0.5)
                .animation(OnboardingLabMotion.fast, value: model.canSubmitSignUp)
                .padding(.top, 22)
                Spacer(minLength: 24)
                OnboardingAuthSwitchLink(
                    prompt: "Already have an account?",
                    action: "Sign in"
                ) { model.showSignIn() }
            }
            .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
            .padding(.top, OnboardingLabMetric.contentTopInset(layout))
            .padding(.bottom, 26)
        }
    }

    private var identitySummary: some View {
        HStack(spacing: 12) {
            if let jpeg = model.pendingProfilePhotoJPEG,
               let image = UIImage(data: jpeg) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                if !model.trimmedDisplayName.isEmpty {
                    Text(model.trimmedDisplayName)
                        .font(OnboardingLabFont.rounded(16, .bold))
                        .foregroundStyle(OnboardingLabColor.espresso)
                }
                if !model.trimmedHandle.isEmpty {
                    Text("@\(model.trimmedHandle)")
                        .font(OnboardingLabFont.text(14, .medium))
                        .foregroundStyle(OnboardingLabColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            OnboardingLabColor.fieldFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var fields: some View {
        VStack(spacing: 12) {
            OnboardingCredentialField(
                systemImage: "envelope.fill",
                placeholder: "Email",
                text: $model.email,
                isSecure: false,
                keyboardType: .emailAddress
            )
            OnboardingCredentialField(
                systemImage: "lock.fill",
                placeholder: "Password (8+ characters)",
                text: $model.password,
                isSecure: true
            )
        }
    }
}
