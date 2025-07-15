//
//  Item.swift
//  VirtualHub
//
//  Created by 진수민 on 7/13/25.
//

import Foundation
import SwiftData

@Model
final class Item {
  var id: UUID
  var name: String
  var vmBundlePath: String
  var mainDiskImagePath: String
  var machineIdentifierPath: String
  var needsInstall: Bool
  var cpuCount: Int
  var memorySize: UInt64 // bytes 단위
  var diskSize: UInt64 // bytes 단위
  
  var isLinux: Bool
  
  var efiVariableStorePath: String?
  var auxiliaryStoragePath: String?
  var hardwareModelPath: String?
  
  init(
    name: String,
    vmBundlePath: String,
    isLinux: Bool,
    cpuCount: Int = 2,
    memorySize: UInt64 = 4 * 1024 * 1024 * 1024, // 4GB
    diskSize: UInt64 = 20 * 1024 * 1024 * 1024, // 20GB
  ) {
    let ID = UUID()
    let path = vmBundlePath + "/\(name)_\(ID).bundle/"
    self.id = ID
    self.name = name
    self.vmBundlePath = path
    self.isLinux = isLinux
    self.cpuCount = cpuCount
    self.memorySize = memorySize
    self.diskSize = diskSize
    
    self.mainDiskImagePath = path + "Disk.img"
    self.machineIdentifierPath = path + "MachineIdentifier"

    if isLinux {
      //for linux
      self.efiVariableStorePath = path + "NVRAM"
      self.auxiliaryStoragePath = nil
      self.hardwareModelPath = nil
    }
    
    else {
      //for macos
      self.efiVariableStorePath = nil
      self.auxiliaryStoragePath = path + "AuxiliaryStorage"
      self.hardwareModelPath = path + "HardwareModel"
    }
    
    self.needsInstall = true
  }
}

