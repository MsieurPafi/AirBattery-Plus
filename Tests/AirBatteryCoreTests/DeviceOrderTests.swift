import XCTest
@testable import AirBatteryCore

private struct Item: ListedDevice, Equatable {
    var hasBattery = true
    var deviceID: String
    var deviceName: String
    var batteryLevel: Int
    var parentName = ""
}

final class DeviceOrderTests: XCTestCase {
    private let mac = Item(deviceID: DeviceOrder.macID, deviceName: "MacBook Pro", batteryLevel: 77)
    private let iPhone = Item(deviceID: "00008150-000A", deviceName: "iPhone", batteryLevel: 90)
    private let oldIPhone = Item(deviceID: "00008030-000B", deviceName: "iPhone", batteryLevel: 85)
    private let watch = Item(deviceID: "watch", deviceName: "Apple Watch", batteryLevel: 93, parentName: "iPhone")
    private let mouse = Item(deviceID: "mouse", deviceName: "MX Anywhere 3", batteryLevel: 95)

    private func names(_ list: [Item]) -> [String] { list.map { "\($0.deviceName) \($0.batteryLevel)" } }

    func testChildFollowsItsParent() {
        XCTAssertEqual(DeviceOrder.nested([watch, mouse, iPhone], thisMac: "MacBook Pro"), [mouse, iPhone, watch])
    }

    func testTwoParentsWithTheSameNameDontDuplicateTheChild() {
        // 2026-10-31: an old iPhone being reset, called "iPhone" like the current one
        let nested = DeviceOrder.nested([iPhone, watch, oldIPhone], thisMac: "MacBook Pro")
        XCTAssertEqual(nested, [iPhone, watch, oldIPhone])
        let sorted = DeviceOrder.sorted([mac] + nested, order: "levelDesc", thisMac: "MacBook Pro")
        XCTAssertEqual(names(sorted), ["MacBook Pro 77", "iPhone 90", "Apple Watch 93", "iPhone 85"])
    }

    func testOrphanChildIsKept() {
        let pencil = Item(deviceID: "pencil", deviceName: "Apple Pencil", batteryLevel: 50, parentName: "iPad")
        XCTAssertEqual(DeviceOrder.nested([pencil, mouse], thisMac: nil), [mouse, pencil])
    }

    func testThisMacStaysFirst() {
        let list = [mac, iPhone, watch, mouse]
        XCTAssertEqual(names(DeviceOrder.sorted(list, order: "levelDesc", thisMac: "MacBook Pro")),
                       ["MacBook Pro 77", "MX Anywhere 3 95", "iPhone 90", "Apple Watch 93"])
        XCTAssertEqual(names(DeviceOrder.sorted(list, order: "levelAsc", thisMac: "MacBook Pro")),
                       ["MacBook Pro 77", "iPhone 90", "Apple Watch 93", "MX Anywhere 3 95"])
        XCTAssertEqual(DeviceOrder.sorted(list, order: "name", thisMac: "MacBook Pro", reversed: true).first, mac)
        XCTAssertEqual(DeviceOrder.sorted(list, order: "default", thisMac: "MacBook Pro"), list)
    }

    func testAnotherMacIsSortedLikeAnyDevice() {
        // Nearcast: the other Macs' batteries carry the same ID, under their own name
        let otherMac = Item(deviceID: DeviceOrder.macID, deviceName: "MacBook Air", batteryLevel: 10)
        let sorted = DeviceOrder.sorted([iPhone, otherMac, mouse], order: "levelDesc", thisMac: "MacBook Pro")
        XCTAssertEqual(sorted.last, otherMac)
    }

    func testGroupsWithoutBatteryGoLast() {
        let speaker = Item(hasBattery: false, deviceID: "speaker", deviceName: "A speaker", batteryLevel: 0)
        XCTAssertEqual(DeviceOrder.sorted([speaker, mouse], order: "levelAsc", thisMac: nil), [mouse, speaker])
    }
}
