import Foundation

enum MockData {
    static let cassettes: [CassetteModel] = [
        CassetteModel(
            id: UUID(),
            name: "cassette 1",
            createdAt: Date().addingTimeInterval(-86400 * 10),
            expiresAt: Date().addingTimeInterval(86400 * 5),
            photos: mockPhotos(count: 23),
            keywords: ["summer", "film", "friends"],
            design: .nr,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 2",
            createdAt: Date().addingTimeInterval(-86400 * 30),
            expiresAt: Date().addingTimeInterval(-86400 * 2),
            photos: mockPhotos(count: 41),
            keywords: ["night", "city"],
            design: .art,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 3",
            createdAt: Date().addingTimeInterval(-86400 * 3),
            expiresAt: Date().addingTimeInterval(86400 * 20),
            photos: mockPhotos(count: 12),
            keywords: ["travel"],
            design: .chf90,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 4",
            createdAt: Date().addingTimeInterval(-86400 * 15),
            expiresAt: Date().addingTimeInterval(86400 * 10),
            photos: mockPhotos(count: 31),
            keywords: ["daily"],
            design: .art,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 5",
            createdAt: Date().addingTimeInterval(-86400 * 7),
            expiresAt: Date().addingTimeInterval(86400 * 3),
            photos: mockPhotos(count: 18),
            keywords: ["concert"],
            design: .chf90,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 6",
            createdAt: Date().addingTimeInterval(-86400 * 45),
            expiresAt: Date().addingTimeInterval(-86400 * 10),
            photos: mockPhotos(count: 27, daysAgo: 50),
            keywords: ["winter", "snow"],
            design: .nr,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 7",
            createdAt: Date().addingTimeInterval(-86400 * 60),
            expiresAt: Date().addingTimeInterval(-86400 * 20),
            photos: mockPhotos(count: 33, daysAgo: 65),
            keywords: ["road trip"],
            design: .art,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 8",
            createdAt: Date().addingTimeInterval(-86400 * 90),
            expiresAt: Date().addingTimeInterval(-86400 * 30),
            photos: mockPhotos(count: 15, daysAgo: 95),
            keywords: ["family"],
            design: .chf90,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 9",
            createdAt: Date().addingTimeInterval(-86400 * 120),
            expiresAt: Date().addingTimeInterval(-86400 * 50),
            photos: mockPhotos(count: 48, daysAgo: 125),
            keywords: ["spring"],
            design: .nr,
            printProgress: 1.0
        ),
        CassetteModel(
            id: UUID(),
            name: "cassette 10",
            createdAt: Date().addingTimeInterval(-86400 * 180),
            expiresAt: Date().addingTimeInterval(-86400 * 80),
            photos: mockPhotos(count: 22, daysAgo: 185),
            keywords: ["festival", "music"],
            design: .art,
            printProgress: 1.0
        )
    ]

    static func mockPhotos(count: Int, daysAgo: Int = 30) -> [BCutPhoto] {
        (0..<count).map { i in
            let randomOffset = Double.random(in: 0...(Double(daysAgo) * 86400))
            return BCutPhoto(
                id: UUID(),
                imageSource: .asset("mock_photo_\(i % 5)"),
                isBCut: i % 3 != 0,
                takenAt: Date().addingTimeInterval(-randomOffset)
            )
        }
    }
}
