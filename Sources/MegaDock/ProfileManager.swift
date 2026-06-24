import AppKit

final class ProfileManager {
    static let shared = ProfileManager()

    private let profilesDir: URL
    private let activeNameFile: URL

    private(set) var activeProfileName: String

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let megadockDir = base.appendingPathComponent("MegaDock")
        profilesDir = megadockDir.appendingPathComponent("profiles")
        activeNameFile = megadockDir.appendingPathComponent("active-profile")
        try? FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)

        activeProfileName = (try? String(contentsOf: activeNameFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Default"

        if profileNames.isEmpty {
            // Migrate existing screen profile if present, otherwise seed from Apple Dock
            let legacy = megadockDir.appendingPathComponent("default-secondary.json")
            if let data = try? Data(contentsOf: legacy),
               let profile = try? JSONDecoder().decode(DockProfile.self, from: data) {
                save(profile, named: "Default")
            } else {
                save(DockProfile.fromAppleDock, named: "Default")
            }
        }
    }

    var profileNames: [String] {
        ((try? FileManager.default.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func profile(named name: String) -> DockProfile? {
        guard let data = try? Data(contentsOf: profilesDir.appendingPathComponent("\(name).json")) else { return nil }
        return try? JSONDecoder().decode(DockProfile.self, from: data)
    }

    func activeProfile() -> DockProfile {
        if let p = profile(named: activeProfileName) { return p }
        // Active profile file is missing — recover to first available profile
        let names = profileNames
        if let first = names.first, let p = profile(named: first) {
            activeProfileName = first
            try? first.write(to: activeNameFile, atomically: true, encoding: .utf8)
            return p
        }
        return DockProfile.fromAppleDock
    }

    func saveActive(_ profile: DockProfile) {
        save(profile, named: activeProfileName)
    }

    func save(_ profile: DockProfile, named name: String) {
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: profilesDir.appendingPathComponent("\(name).json"))
        }
    }

    @discardableResult
    func activate(profileNamed name: String) -> DockProfile? {
        guard profileNames.contains(name) else { return nil }
        activeProfileName = name
        try? name.write(to: activeNameFile, atomically: true, encoding: .utf8)
        return profile(named: name)
    }

    func createProfile(named name: String) {
        guard !profileNames.contains(name) else { return }
        save(activeProfile(), named: name)
    }

    func deleteProfile(named name: String) {
        guard name != activeProfileName else { return }
        try? FileManager.default.removeItem(at: profilesDir.appendingPathComponent("\(name).json"))
    }
}
