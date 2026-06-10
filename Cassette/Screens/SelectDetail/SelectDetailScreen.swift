import SwiftUI

struct SelectDetailScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var keywordInput: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()
                .onTapGesture { hideKeyboard() }

            VStack(spacing: 0) {
                // 상단 헤더
                HStack {
                    Button { dismiss() } label: {
                        Image("button_chevronLeft")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Text("2 / 3")
                        .font(.cutiveMono(14))
                        .foregroundColor(.appGray)
                    Spacer()
                    Button { cassetteData.shouldDismiss = true } label: {
                        Image("button_x")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Text("cassette detail")
                    .font(.cutiveMono(24))
                    .foregroundColor(.appBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                // 이름 입력
                VStack(alignment: .leading, spacing: 8) {
                    Text("name")
                        .font(.cutiveMono(13))
                        .foregroundColor(.appGray)
                    TextField("cassette name", text: $cassetteData.name)
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .padding(.vertical, 12)
                        .overlay(Rectangle().frame(height: 1).foregroundColor(.appBlack), alignment: .bottom)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // 키워드 입력
                VStack(alignment: .leading, spacing: 8) {
                    Text("keywords  (optional)")
                        .font(.cutiveMono(13))
                        .foregroundColor(.appGray)

                    // 입력된 키워드 chips
                    if !cassetteData.keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(cassetteData.keywords, id: \.self) { kw in
                                    HStack(spacing: 4) {
                                        Text(kw)
                                            .font(.cutiveMono(13))
                                            .foregroundColor(.appBlack)
                                        Button {
                                            cassetteData.keywords.removeAll { $0 == kw }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10))
                                                .foregroundColor(.appGray)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .overlay(Rectangle().stroke(Color.appGray, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    HStack {
                        TextField("add keyword", text: $keywordInput)
                            .font(.cutiveMono(16))
                            .foregroundColor(.appBlack)
                            .onSubmit { addKeyword() }
                        Button { addKeyword() } label: {
                            Text("add")
                                .font(.cutiveMono(14))
                                .foregroundColor(keywordInput.isEmpty ? .appGray : .appBlack)
                        }
                        .disabled(keywordInput.isEmpty)
                    }
                    .padding(.vertical, 12)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(.appBlack), alignment: .bottom)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // 만료일 안내
                HStack {
                    Text("expires in")
                        .font(.cutiveMono(13))
                        .foregroundColor(.appGray)
                    Spacer()
                    Text("30 days")
                        .font(.cutiveMono(13))
                        .foregroundColor(.appBlack)
                }
                .padding(.horizontal, 24)

                Spacer()
            }

            // 하단 Next 버튼
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    NavigationLink {
                        SelectDesignScreen()
                            .environmentObject(appState)
                            .environmentObject(cassetteData)
                    } label: {
                        Text("next →")
                            .font(.cutiveMono(16))
                            .foregroundColor(cassetteData.name.isEmpty ? .appGray : .appBlack)
                    }
                    .disabled(cassetteData.name.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color.appBackground)
        }
        .navigationBarHidden(true)
    }

    private func addKeyword() {
        let kw = keywordInput.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty, !cassetteData.keywords.contains(kw) else { return }
        cassetteData.keywords.append(kw)
        keywordInput = ""
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
