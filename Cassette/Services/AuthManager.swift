import SwiftUI
import Combine
import Supabase
import AuthenticationServices
import CryptoKit

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool = false
    @Published var userID: UUID? = nil

    private var currentNonce: String = ""
    private var signInContinuation: CheckedContinuation<Void, Error>?

    func checkSession() async {
        let session = try? await supabase.auth.session
        isSignedIn = session != nil
        userID = session?.user.id
    }

    func signInWithApple() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            self.currentNonce = randomNonce()

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(currentNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        await checkSession()
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        isSignedIn = false
        userID = nil
    }

    // MARK: - Helpers

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            Task { @MainActor in
                self.signInContinuation?.resume(throwing: AuthError.tokenMissing)
                self.signInContinuation = nil
            }
            return
        }

        Task { @MainActor in
            let nonce = self.currentNonce
            do {
                try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: token, nonce: nonce)
                )
                self.signInContinuation?.resume()
            } catch {
                self.signInContinuation?.resume(throwing: error)
            }
            self.signInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.signInContinuation?.resume(throwing: error)
            self.signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum AuthError: Error {
    case tokenMissing
}
