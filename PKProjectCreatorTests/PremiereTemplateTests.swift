import Foundation
import Testing
@testable import PKProjectCreator

/// Uses small fixture files in temporary folders. Never the real master template, KIOXIA or WORK.
@MainActor
struct PremiereTemplateTests {
    private struct InjectedFailure: Error {}

    private let files = FileManager.default
    private let fixtureBytes = Data("<?xml version=\"1.0\"?><PremiereData Version=\"3\">fixture · Lễ hội</PremiereData>".utf8)
    private let outputPath = "2026/2026 - 11 - 12 Event Develon/07_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj"

    private func makeFolder(_ label: String) throws -> URL {
        let url = files.temporaryDirectory.appending(path: "PK\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A master template fixture, with its attributes captured so tests can prove it was not changed.
    private func makeMaster(in folder: URL, name: String = "Year - Month - Day - Name 2026.prproj") throws -> URL {
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        try fixtureBytes.write(to: url)
        return url
    }

    private func snapshot(_ url: URL) throws -> [String] {
        let attributes = try files.attributesOfItem(atPath: url.plainPath)
        return [
            String(describing: attributes[.size]), String(describing: attributes[.modificationDate]),
            String(describing: attributes[.posixPermissions]), try Data(contentsOf: url).base64EncodedString(),
            String(describing: try files.contentsOfDirectory(atPath: url.deletingLastPathComponent().plainPath).sorted()),
        ]
    }

    private func plan(in destination: URL, folders: [FolderNode]? = nil) throws -> ProjectCreationPlan {
        let template = FolderTemplate.standardProduction()
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        return ProjectCreationPlan(
            date: date, type: .event, projectName: "Develon",
            templateID: template.id, templateName: template.name, folders: folders ?? template.nodes,
            destinationFolderURL: destination, useYearFolder: true,
            createsPremiereProject: true, premiereFolder: ["07_Project", "Premiere Pro"]
        )
    }

    private func error(_ body: () async throws -> Void) async -> ProjectCreationError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? ProjectCreationError
        }
    }

    // MARK: End to end

    @Test func createsFoldersAndCopiesTheMasterUnderTheGeneratedName() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let before = try snapshot(master)

        let project = try await ProjectCreationService().create(try plan(in: destination), in: destination, premiereTemplate: master)

        let output = destination.appending(path: outputPath)
        #expect(try Data(contentsOf: output) == fixtureBytes)
        #expect(try files.attributesOfItem(atPath: output.plainPath)[.size] as? Int == fixtureBytes.count)
        let root = destination.appending(path: "2026/2026 - 11 - 12 Event Develon")
        let entries = files.enumerator(atPath: root.plainPath)?.compactMap { $0 as? String } ?? []
        #expect(entries.count == 20)
        #expect(entries.filter { $0.hasSuffix(".prproj") } == ["07_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj"])
        #expect(try files.contentsOfDirectory(atPath: destination.appending(path: "2026").plainPath) == ["2026 - 11 - 12 Event Develon"])
        #expect(project.hasPremiereProject)
        #expect(project.premiereProjectRelativePath == "07_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj")
        // The master was only read: same bytes, size, date, permissions, and nothing new beside it.
        #expect(try snapshot(master) == before)
    }

    @Test func appCreatesTheFullProjectWithRealPermissions() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let before = try snapshot(master)
        let app = AppState(directory: nil)
        app.settings.openFinderAfterCreation = false
        app.settings.openPremiereAfterCreation = false
        app.setDestination(destination)
        app.setPremiereTemplate(master)
        app.draft.date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        app.draft.projectName = "Develon"

        #expect(app.premiereTemplate.templateLabel == "Ready to copy")
        #expect(app.creationBlocker == nil)
        #expect(app.creationStatus.text.contains("and the Premiere project"))
        app.createProject()
        await app.creationTask?.value

        #expect(app.notice == nil)
        #expect(app.createdProject?.hasPremiereProject == true)
        #expect(try Data(contentsOf: destination.appending(path: outputPath)) == fixtureBytes)
        #expect(try snapshot(master) == before)
    }

    // MARK: DaVinci Resolve

    private func resolvePlan(in destination: URL, folders: [FolderNode]? = nil) throws -> ProjectCreationPlan {
        let base = try plan(in: destination, folders: folders)
        return ProjectCreationPlan(
            date: base.date, type: base.type, projectName: base.projectName,
            templateID: base.templateID, templateName: base.templateName, folders: base.folders,
            destinationFolderURL: destination, useYearFolder: true,
            createsPremiereProject: true, premiereFolder: ["07_Project", "Premiere Pro"],
            createsResolveProject: true, resolveFolder: ["07_Project", "DaVinci Resolve"]
        )
    }

    private static let masterFolder = "/Volumes/WORK/TÀI NGUYÊN /PROJECT MODEL"

    /// Resolve's settings as a hex `<FieldsBlob>`: "SetupBA" holding a zstd-compressed protobuf, laid out like a real
    /// export. Field 36 holds the Working Folders (37 unknown, 38 gallery, 39 cache, 40 proxy, 124 media/name).
    private func setupBlob(workingFolders: [UInt8]) throws -> String {
        func u32(_ value: Int) -> [UInt8] { withUnsafeBytes(of: UInt32(value).bigEndian, Array.init) }
        let header: [UInt8] = [0x08, 0x01] // field 1 = 1, a plain number before the folders
        let settings = header + ResolveWorkingFolders.field(36, u32(2) + u32(workingFolders.count) + workingFolders)
        let payload = [0x81] + (try ResolveWorkingFolders.compress(settings))
        let array = u32(1) + u32(payload.count) + payload
        let name = Array("SetupBA".data(using: .utf16BigEndian)!)
        let tail = u32(4) + Array("Tail".utf8) // a later setting that must survive unchanged
        let blob = u32(1) + u32(2) + u32(name.count) + name + u32(0x0c) + [0] + u32(array.count) + array + tail
        return "<FieldsBlob>" + blob.map { String(format: "%02x", $0) }.joined() + "</FieldsBlob>"
    }

    private func masterWorkingFolders(media: Bool = true) -> [UInt8] {
        let folder = Self.masterFolder + "/PROJECT MODEL"
        return [37, 38, 39, 40].flatMap { ResolveWorkingFolders.field($0, Array(($0 == 38 ? "/Volumes/WORK/.gallery" : folder).utf8)) }
            + (media ? ResolveWorkingFolders.field(124, Array((Self.masterFolder + "/Project Model").utf8)) : [])
    }

    /// The decompressed Resolve settings of a `.drp`'s `project.xml`.
    private func settings(in xml: String) throws -> [UInt8] {
        let hex = try #require(xml.firstMatch(of: /<FieldsBlob>([0-9a-f]+)<\/FieldsBlob>/)?.output.1)
        let bytes = stride(from: 0, to: hex.count, by: 2).map { offset -> UInt8 in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
        }
        let magic = try #require(bytes.firstRange(of: [0x28, 0xb5, 0x2f, 0xfd]))
        #expect(bytes.suffix(8) == [0, 0, 0, 4] + Array("Tail".utf8))
        return try ResolveWorkingFolders.decompress(Array(bytes[magic.lowerBound..<(bytes.count - 8)]))
    }

    /// A small real `.drp`: a zip with `project.xml` first, like Resolve's own export.
    private func makeDrp(in folder: URL, name: String = "Project Template.drp", projectXML: String? = nil) throws -> URL {
        let source = try makeFolder("DrpSource")
        defer { try? files.removeItem(at: source) }
        let xml = try projectXML ?? "<?xml version=\"1.0\"?><Project><ProjectName>Project Model</ProjectName><Name>Project Model.Cfg</Name>\(setupBlob(workingFolders: masterWorkingFolders()))</Project>"
        try xml.write(to: source.appending(path: "project.xml"), atomically: true, encoding: .utf8)
        try files.createDirectory(at: source.appending(path: "MediaPool/Master"), withIntermediateDirectories: true)
        try "<MpFolder>Lễ hội</MpFolder>".write(to: source.appending(path: "MediaPool/Master/MpFolder.xml"), atomically: true, encoding: .utf8)
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        let zip = Process()
        zip.executableURL = URL(filePath: "/usr/bin/zip")
        zip.arguments = ["-q", "-X", "-D", url.plainPath, "project.xml", "MediaPool/Master/MpFolder.xml"]
        zip.currentDirectoryURL = source
        try zip.run()
        zip.waitUntilExit()
        #expect(zip.terminationStatus == 0)
        return url
    }

    /// One entry of a zip, read with the system `unzip`.
    private func entry(_ path: String, of zipURL: URL) throws -> String {
        let unzip = Process(), pipe = Pipe()
        unzip.executableURL = URL(filePath: "/usr/bin/unzip")
        unzip.arguments = ["-p", zipURL.plainPath, path]
        unzip.standardOutput = pipe
        try unzip.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        unzip.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    @Test func copiesTheResolveMasterBesideThePremiereProject() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let resolveMaster = try makeDrp(in: work)
        let before = try snapshot(resolveMaster)

        let plan = try resolvePlan(in: destination)
        #expect(plan.resolveOutputRelativePath == "07_Project/DaVinci Resolve/2026 - 11 - 12 Event Develon.drp")
        _ = try await ProjectCreationService().create(plan, in: destination, premiereTemplate: master, resolveTemplate: resolveMaster)

        let root = destination.appending(path: "2026/2026 - 11 - 12 Event Develon")
        // The copy carries the generated name inside, so Resolve shows it on import; everything else is unchanged.
        let copy = root.appending(path: "07_Project/DaVinci Resolve/2026 - 11 - 12 Event Develon.drp")
        let xml = try entry("project.xml", of: copy)
        #expect(xml.contains("<ProjectName>2026 - 11 - 12 Event Develon</ProjectName>"))
        #expect(xml.contains("<Name>Project Model.Cfg</Name>"))
        #expect(try entry("MediaPool/Master/MpFolder.xml", of: copy) == "<MpFolder>Lễ hội</MpFolder>")
        // Media, proxy and cache point at the final DaVinci Resolve folder (not the staging one); the rest is unchanged.
        let folder = root.appending(path: "07_Project/DaVinci Resolve").plainPath.precomposedStringWithCanonicalMapping
        let masterPath = Self.masterFolder + "/PROJECT MODEL"
        let expected: [UInt8] = [0x08, 0x01] + ResolveWorkingFolders.field(36, try {
            let folders = ResolveWorkingFolders.field(37, Array(masterPath.utf8)) + ResolveWorkingFolders.field(38, Array("/Volumes/WORK/.gallery".utf8))
                + ResolveWorkingFolders.field(39, Array(folder.utf8)) + ResolveWorkingFolders.field(40, Array(folder.utf8))
                + ResolveWorkingFolders.field(124, Array((folder + "/2026 - 11 - 12 Event Develon").utf8))
            return withUnsafeBytes(of: UInt32(2).bigEndian, Array.init) + withUnsafeBytes(of: UInt32(folders.count).bigEndian, Array.init) + folders
        }())
        #expect(try settings(in: xml) == expected)
        #expect(try Data(contentsOf: root.appending(path: "07_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj")) == fixtureBytes)
        #expect(try snapshot(resolveMaster) == before)
    }

    @Test func badResolveSourcesAreRefusedAndNothingIsCreated() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let service = ProjectCreationService()
        let master = try makeMaster(in: work)

        #expect(await error { _ = try await service.create(try resolvePlan(in: destination), in: destination, premiereTemplate: master) } == .resolveTemplateUnavailable)
        let wrong = try makeMaster(in: work, name: "Other.prproj")
        #expect(await error { _ = try await service.create(try resolvePlan(in: destination), in: destination, premiereTemplate: master, resolveTemplate: wrong) } == .resolve(.wrongExtension("Other.prproj")))
        let noResolveFolder = FolderTemplate.standardProduction().nodes.map { node in
            var node = node
            node.children.removeAll { $0.name == "DaVinci Resolve" }
            return node
        }
        let drp = try makeDrp(in: work)
        #expect(await error { _ = try await service.create(try resolvePlan(in: destination, folders: noResolveFolder), in: destination, premiereTemplate: master, resolveTemplate: drp) } == .resolveFolderMissing("07_Project/DaVinci Resolve"))

        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
    }

    @Test func aResolveFileWithoutAProjectNameIsRefusedAndRolledBack() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let unnamed = try makeDrp(in: work, projectXML: "<Project></Project>")
        let failure = await error {
            _ = try await ProjectCreationService().create(try resolvePlan(in: destination), in: destination, premiereTemplate: master, resolveTemplate: unnamed)
        }
        guard case .resolve(.resolveFileFailed) = failure else {
            Issue.record("Expected a project name failure, got \(String(describing: failure))")
            return
        }
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
    }

    @Test func missingWorkingFoldersAreAddedAndMissingSettingsAreRefused() throws {
        let xml = "<Project>\(try setupBlob(workingFolders: masterWorkingFolders(media: false)))</Project>"
        let result = try ResolveWorkingFolders.apply(folder: URL(filePath: "/Volumes/X/New"), projectName: "Name", to: xml)
        let added = try settings(in: result)
        let media = ResolveWorkingFolders.field(124, Array("/Volumes/X/New/Name".utf8))
        #expect(added.suffix(media.count).elementsEqual(media))
        #expect(added.firstRange(of: ResolveWorkingFolders.field(39, Array("/Volumes/X/New".utf8))) != nil)

        #expect(throws: PremiereTemplateError.self) {
            try ResolveWorkingFolders.apply(folder: URL(filePath: "/Volumes/X"), projectName: "Name", to: "<Project><FieldsBlob>00</FieldsBlob></Project>")
        }
    }

    @Test func projectNamesAreEscapedForXML() {
        #expect(ResolveProjectFile.escaped("A & B <C> \"D\" 'E'") == "A &amp; B &lt;C&gt; &quot;D&quot; &apos;E&apos;")
    }

    @Test func oldSettingsFilesKeepTheSuggestedResolveTemplate() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(old.resolveTemplateURL == AppSettings.suggestedResolveTemplateURL)
        var cleared = AppSettings()
        cleared.resolveTemplateURL = nil
        let reloaded = try JSONDecoder().decode(AppSettings.self, from: try JSONEncoder().encode(cleared))
        #expect(reloaded.resolveTemplateURL == nil)
    }

    // MARK: Refusals before anything is written

    @Test func badSourcesAreRefusedAndNothingIsCreated() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let service = ProjectCreationService()

        let missing = work.appending(path: "Gone.prproj")
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: missing) } == .premiere(.missing("Gone.prproj")))

        let text = try makeMaster(in: work, name: "Notes.txt")
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: text) } == .premiere(.wrongExtension("Notes.txt")))

        let folder = work.appending(path: "Bundle.prproj", directoryHint: .isDirectory)
        try files.createDirectory(at: folder, withIntermediateDirectories: false)
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: folder) } == .premiere(.notAFile("Bundle.prproj")))

        let locked = try makeMaster(in: work, name: "Locked.prproj")
        try files.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.plainPath)
        defer { try? files.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.plainPath) }
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: locked) } == .premiere(.notReadable("Locked.prproj")))

        // The folder template has no 07_Project/Premiere Pro to copy into.
        let master = try makeMaster(in: work)
        let noProjectFolder = FolderTemplate.standardProduction().nodes.filter { $0.name != "07_Project" }
        #expect(await error { _ = try await service.create(try plan(in: destination, folders: noProjectFolder), in: destination, premiereTemplate: master) } == .premiereFolderMissing("07_Project/Premiere Pro"))

        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
    }

    // MARK: Failures during the copy

    @Test func copyFailureCleansUpStagingAndKeepsTheMaster() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let before = try snapshot(master)
        let service = ProjectCreationService(willWrite: { url in
            if url.pathExtension == "prproj" { throw InjectedFailure() }
        })

        let failure = await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: master) }

        guard case .failed = failure else { Issue.record("expected .failed, got \(String(describing: failure))"); return }
        #expect(failure?.localizedDescription.contains("master template was not changed") == true)
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
        #expect(try snapshot(master) == before)
    }

    @Test func copyRefusesCollisionsAndMissingFolders() throws {
        let folder = try makeFolder("Output"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: folder); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)

        let existing = folder.appending(path: "2026 - 11 - 12 Event Develon.prproj")
        try Data("someone else's edit".utf8).write(to: existing)
        #expect(throws: PremiereTemplateError.outputExists("2026 - 11 - 12 Event Develon.prproj")) {
            try PremiereTemplateService.copy(master, into: folder, generatedName: "2026 - 11 - 12 Event Develon")
        }
        #expect(try Data(contentsOf: existing) == Data("someone else's edit".utf8))

        #expect(throws: PremiereTemplateError.destinationFolderMissing("Nowhere")) {
            try PremiereTemplateService.copy(master, into: folder.appending(path: "Nowhere"), generatedName: "X")
        }

        let copy = try PremiereTemplateService.copy(master, into: folder, generatedName: "2026 - 11 - 12 Event Lễ hội (A&B)")
        #expect(copy.lastPathComponent == "2026 - 11 - 12 Event Lễ hội (A&B).prproj")
        #expect(files.contentsEqual(atPath: copy.plainPath, andPath: master.plainPath))
    }

    @Test func projectCollisionLeavesTheExistingPremiereProjectAlone() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let plan = try plan(in: destination)
        _ = try await ProjectCreationService().create(plan, in: destination, premiereTemplate: master)
        let edited = destination.appending(path: outputPath)
        try Data("edited in Premiere".utf8).write(to: edited)

        let failure = await error { _ = try await ProjectCreationService().create(plan, in: destination, premiereTemplate: master) }

        #expect(failure == .alreadyExists("2026 - 11 - 12 Event Develon"))
        #expect(try Data(contentsOf: edited) == Data("edited in Premiere".utf8))
    }

    // MARK: Template states, independent of the destination drive

    @Test func templateStatesAreReportedIndependentlyOfKIOXIA() throws {
        let system = FakeSystem()
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        let destination = URL(filePath: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT")
        let master = URL(filePath: "/Volumes/WORK/Templates/Master.prproj")
        system.existingPaths = [destination.plainPath, master.plainPath]
        let app = AppState(directory: nil, fileAccess: FileAccessService(system: system))
        app.setDestination(destination)
        app.setPremiereTemplate(master)
        app.draft.projectName = "Develon"
        #expect(app.premiereTemplate.templateLabel == "Ready to copy")
        #expect(app.creationBlocker == nil)

        func templateAfterRefresh() -> String {
            app.refreshResources()
            return app.premiereTemplate.templateLabel
        }

        system.unreadablePaths = [master.plainPath]
        #expect(templateAfterRefresh() == "Permission denied")
        system.unreadablePaths = []
        system.deniedPaths = [master.plainPath]
        #expect(templateAfterRefresh() == "Permission denied")
        system.deniedPaths = []

        system.existingPaths.remove(master.plainPath)
        #expect(templateAfterRefresh() == "Template missing")
        system.existingPaths.insert(master.plainPath)

        system.unmount("WORK")
        #expect(templateAfterRefresh() == "WORK disconnected")
        #expect(app.destination.state == .authorized)
        #expect(app.creationBlocker?.text.contains("“WORK” is disconnected") == true)
        // Folders only stays possible while WORK is away, by the user's explicit choice.
        #expect(!app.needsFoldersOnlyConfirmation)
        app.draft.createPremiere = false
        #expect(app.creationBlocker == nil)
        #expect(app.needsFoldersOnlyConfirmation)
        app.draft.createPremiere = true

        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        system.unmount("KIOXIA")
        #expect(templateAfterRefresh() == "Ready to copy")
        #expect(app.destination.state == .disconnected)
        #expect(app.creationBlocker?.text.contains("“KIOXIA” is disconnected") == true)

        // D: both drives away. Both are reported, and Create Project does nothing at all.
        system.unmount("WORK")
        #expect(templateAfterRefresh() == "WORK disconnected")
        #expect(app.destination.state == .disconnected)
        #expect(app.creationBlocker != nil)
        app.createProject()
        #expect(app.creationTask == nil)
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        // A: both back, everything ready again.
        #expect(templateAfterRefresh() == "Ready to copy")
        #expect(app.destination.state == .authorized)
        #expect(app.creationBlocker == nil)

        system.staleBookmarks = true
        system.canMakeBookmarks = false
        #expect(templateAfterRefresh() == "Bookmark stale")
    }

    @Test func aFolderNamedLikeATemplateIsInvalid() {
        let system = FakeSystem()
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        let bundle = URL(filePath: "/Volumes/WORK/Templates/Bundle.prproj", directoryHint: .isDirectory)
        system.existingPaths = [bundle.plainPath]
        system.directoryPaths = [bundle.plainPath]
        let service = FileAccessService(system: system)
        let grant = try? service.authorize(bundle, readOnly: true)
        let status = service.check(bookmark: grant?.bookmark, lastKnownURL: bundle, volume: grant?.volume, readOnly: true, fileExtension: "prproj").status
        #expect(status.templateLabel == "Invalid template file")
    }
}
