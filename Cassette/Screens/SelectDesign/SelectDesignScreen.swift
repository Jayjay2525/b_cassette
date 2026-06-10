import SwiftUI

struct SelectDesignScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    // sheet dismiss를 위해 루트까지 올라가야 함
    @Environment(\.dismiss) var dismissSheet

    @State private var showExitAlert: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 헤더
                HStack {
                    Button { dismiss() } label: {
                        Image("button_chevronLeft")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Text("3 / 3")
                        .font(.cutiveMono(14))
                        .foregroundColor(.appGray)
                    Spacer()
                    Button { showExitAlert = true } label: {
                        Image("button_x")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Text("select design")
                    .font(.cutiveMono(24))
                    .foregroundColor(.appBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                // 디자인 선택 목록
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(CassetteDesign.allCases, id: \.self) { design in
                            DesignOptionCell(
                                design: design,
                                isSelected: cassetteData.design == design
                            ) {
                                cassetteData.design = design
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }

            // ── Done 버튼 (ZStack 최상단 고정) ──
            VStack(spacing: 0) {
                Button {
                    let newCassette = cassetteData.buildCassette()
                    appState.addCassette(newCassette)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        dismissSheet()
                    }
                } label: {
                    Text("done")
                        .font(.cutiveMono(18))
                        .foregroundColor(.appWhite)
                        .frame(width: 183, height: 48)
                        .background(Capsule().fill(Color(hex: "#555555")))
                }
                Spacer().frame(height: 41)
            }
            .frame(maxWidth: .infinity)
            .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
        }
        .navigationBarHidden(true)
        .alert("discard cassette?", isPresented: $showExitAlert) {
            Button("discard", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("your selections will not be saved.")
        }
    }
}

struct DesignOptionCell: View {
    let design: CassetteDesign
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(design.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 77)

                VStack(alignment: .leading, spacing: 4) {
                    Text(design.rawValue.replacingOccurrences(of: "cassette_", with: ""))
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                }

                Spacer()

                if isSelected {
                    Circle()
                        .fill(Color.appBlack)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .stroke(Color.appGray, lineWidth: 1)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(16)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? Color.appBlack : Color.appGray, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}
