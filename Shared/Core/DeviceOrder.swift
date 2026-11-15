//
//  DeviceOrder.swift
//  Shared by the app, the widget, the login helper and abt; tested with `swift test`.
//
//  Order of the device list in the menu, the Dock and the widget: each device right after
//  its parent (an iPhone's Watch, an iPad's Pencil, AirPods after their case), then the sort
//  setting. Used by AirBatteryModel.getAll() and AirBatteryModel.sortForDisplay().
//

import Foundation

/// What the order needs to know about a device (Device conforms in AirBatteryModel.swift).
protocol ListedDevice {
    var hasBattery: Bool { get }
    var deviceID: String { get }
    var deviceName: String { get }
    var batteryLevel: Int { get }
    var parentName: String { get }
}

enum DeviceOrder {
    /// ID of the Mac's own battery in the lists (`ib2ab`), also for the other Macs over Nearcast.
    static let macID = "@MacInternalBattery"

    /// Each device without a parent, followed by its children; devices whose parent is this Mac
    /// come first. Children point to their parent by name: when two parents share a name (an
    /// iPhone being reset is called "iPhone" again), each used to get every child, so a Watch
    /// showed twice. A device now appears once, under the first parent with that name.
    static func nested<D: ListedDevice>(_ list: [D], thisMac: String?) -> [D] {
        var order: [Int] = []
        var placed = Set<Int>()
        func place(_ index: Int) {
            if placed.insert(index).inserted { order.append(index) }
        }
        for index in list.indices where list[index].parentName == thisMac { place(index) }
        for index in list.indices where list[index].parentName == "" {
            place(index)
            for child in list.indices where list[child].parentName == list[index].deviceName { place(child) }
        }
        // Children whose parent isn't listed
        for index in list.indices { place(index) }
        return order.map { list[$0] }
    }

    /// The list sorted by `order` ("default", "name", "levelAsc" or "levelDesc"). Groups are
    /// sorted as a whole: a device with its children. A group's level is its lowest one; groups
    /// without a battery go last. This Mac stays first, whatever the order: "default" keeps the
    /// discovery order, where the callers put it first.
    static func sorted<D: ListedDevice>(_ list: [D], order: String, thisMac: String?, reversed: Bool = false) -> [D] {
        if order == "default" { return list }
        let names = Set(list.map { $0.deviceName })
        // Peripherals reported by this Mac carry its name as parent: sort them on their own.
        func isChild(_ d: D) -> Bool {
            return d.parentName != "" && d.parentName != thisMac && names.contains(d.parentName)
        }
        var groups: [[D]] = []
        var grouped = Set<Int>()
        for index in list.indices where !isChild(list[index]) && grouped.insert(index).inserted {
            var group = [list[index]]
            for child in list.indices where isChild(list[child]) && list[child].parentName == list[index].deviceName {
                if grouped.insert(child).inserted { group.append(list[child]) }
            }
            groups.append(group)
        }
        func lowestLevel(_ group: [D]) -> Int? {
            return group.filter { $0.hasBattery }.map { $0.batteryLevel }.min()
        }
        func byName(_ a: [D], _ b: [D]) -> Bool {
            return a[0].deviceName.localizedStandardCompare(b[0].deviceName) == .orderedAscending
        }
        groups.sort { a, b in
            if order == "name" { return byName(a, b) }
            guard let levelA = lowestLevel(a) else { return false }
            guard let levelB = lowestLevel(b) else { return true }
            if levelA != levelB { return order == "levelAsc" ? levelA < levelB : levelA > levelB }
            return byName(a, b)
        }
        if reversed { groups.reverse() }
        if let mac = groups.firstIndex(where: { $0[0].deviceID == macID && $0[0].deviceName == thisMac }) {
            groups.insert(groups.remove(at: mac), at: 0)
        }
        return groups.flatMap { $0 }
    }
}
