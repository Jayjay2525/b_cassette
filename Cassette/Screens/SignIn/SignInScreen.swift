import SwiftUI
import AuthenticationServices

struct SignInScreen: View {
    let onComplete: () -> Void

    @StateObject private var auth = AuthManager.shared
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("signin_asset")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 24)

                Text("B_Cassette")
                    .font(.cutiveMono(28))
                    .foregroundColor(.appBlack)
                    .padding(.top, 32)

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: 280, height: 52)
                    .onTapGesture {
                        Task {
                            isLoading = true
                            try? await auth.signInWithApple()
                            isLoading = false
                            if auth.isSignedIn { onComplete() }
                        }
                    }

                Button {
                    onComplete()
                } label: {
                    VStack(spacing: 4) {
                        Text("skip for now")
                            .font(.appBody)
                            .foregroundColor(.appDarkGray)
                        Image("underline")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 122)
                    }
                }
                .padding(.top, 16)

                Spacer().frame(height: 60)
            }
        }
    }
}

#Preview {
    SignInScreen(onComplete: {})
}
