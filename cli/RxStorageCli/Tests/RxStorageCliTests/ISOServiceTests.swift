import Foundation
import Testing

@testable import RxStorageCli

@Suite("ISOService Tests")
struct ISOServiceTests {
    static let testISOPath: String = {
        let thisFile = #filePath
        let testsDir = (thisFile as NSString).deletingLastPathComponent
        return (testsDir as NSString).appendingPathComponent("test-assets/test-media.iso")
    }()

    @Test("Mount ISO returns a valid mount point")
    func testMountISO() throws {
        let mountPoint = ISOService.mount(isoPath: Self.testISOPath)
        try #require(mountPoint != nil, "ISO should mount successfully")

        let fm = FileManager.default
        var isDir: ObjCBool = false
        #expect(fm.fileExists(atPath: mountPoint!, isDirectory: &isDir))
        #expect(isDir.boolValue)

        ISOService.unmount(mountPoint: mountPoint!)
    }

    @Test("Mounted ISO contains expected files")
    func testISOContainsFiles() throws {
        let mountPoint = try #require(ISOService.mount(isoPath: Self.testISOPath))
        defer { ISOService.unmount(mountPoint: mountPoint) }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: mountPoint) else {
            Issue.record("Cannot enumerate mounted ISO")
            return
        }

        var files: [String] = []
        while let file = enumerator.nextObject() as? String {
            let fullPath = (mountPoint as NSString).appendingPathComponent(file)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                files.append(file)
            }
        }

        #expect(files.contains("test-image.jpg"))
        #expect(files.contains("test-video.mp4"))
        #expect(files.contains("sample.png"))
    }

    @Test("Unmount cleans up mount point")
    func testUnmountCleansUp() throws {
        let mountPoint = try #require(ISOService.mount(isoPath: Self.testISOPath))

        ISOService.unmount(mountPoint: mountPoint)

        // After unmount, the mount point directory should be removed
        #expect(!FileManager.default.fileExists(atPath: mountPoint))
    }

    @Test("Mount nonexistent ISO returns nil")
    func testMountNonexistentISO() {
        let result = ISOService.mount(isoPath: "/nonexistent/path/fake.iso")
        #expect(result == nil)
    }
}
