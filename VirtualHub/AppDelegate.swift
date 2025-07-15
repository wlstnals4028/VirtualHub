//
//  AppDelegate.swift
//  VirtualHub
//
//  Created by 진수민 on 7/13/25.
//

import Virtualization
import SwiftData
import SwiftUI
import AppKit

//var vmBundlePath = NSHomeDirectory() + "/GUI Linux VM.bundle/"
//var mainDiskImagePath = vmBundlePath + "Disk.img"
//var efiVariableStorePath = vmBundlePath + "NVRAM"
//var machineIdentifierPath = vmBundlePath + "MachineIdentifier"

class AppDelegate: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate, ObservableObject {
  
  @IBOutlet var window: NSWindow!
  
  @IBOutlet weak var virtualMachineView: VZVirtualMachineView!
  
  public var virtualMachine: VZVirtualMachine!
  
  private var installerISOPath: URL?
    
  override init() {
    super.init()
  }
  
  private func createVMBundle(vmBundlePath: String) {
    do {
      try FileManager.default.createDirectory(atPath: vmBundlePath, withIntermediateDirectories: false)
    } catch {
      fatalError("Failed to create “GUI Linux VM.bundle.”")
    }
  }
  
  // Create an empty disk image for the virtual machine.
  private func createMainDiskImage(DiskSize: UInt64, mainDiskImagePath: String) {
    let diskCreated = FileManager.default.createFile(atPath: mainDiskImagePath, contents: nil, attributes: nil)
    if !diskCreated {
      fatalError("Failed to create the main disk image.")
    }
    
    guard let mainDiskFileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: mainDiskImagePath)) else {
      fatalError("Failed to get the file handle for the main disk image.")
    }
    
    do {
      // 20 GB disk space.
      try mainDiskFileHandle.truncate(atOffset: DiskSize)
    } catch {
      fatalError("Failed to truncate the main disk image.")
    }
  }
  
  // MARK: Create device configuration objects for the virtual machine.
  
  private func createBlockDeviceConfiguration(mainDiskImagePath: String) -> VZVirtioBlockDeviceConfiguration {
    guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: mainDiskImagePath), readOnly: false) else {
      fatalError("Failed to create main disk attachment.")
    }
    
    let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
    return mainDisk
  }
  
  private func computeCPUCount(CPUCount : Int) -> Int {
    var virtualCPUCount = CPUCount
    
    virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
    virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)
    
    return virtualCPUCount
  }
  
  private func computeMemorySize(MemorySize : UInt64) -> UInt64 {
    //var memorySize = (8 * 1024 * 1024 * 1024) as UInt64 // 4 GiB
    var memorySize = MemorySize
    
    memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
    memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)
    
    return memorySize
  }
  
  private func createAndSaveMachineIdentifier(machineIdentifierPath: String) -> VZGenericMachineIdentifier {
    let machineIdentifier = VZGenericMachineIdentifier()
    
    // Store the machine identifier to disk so you can retrieve it for subsequent boots.
    try! machineIdentifier.dataRepresentation.write(to: URL(fileURLWithPath: machineIdentifierPath))
    return machineIdentifier
  }
  
  private func retrieveMachineIdentifier(machineIdentifierPath: String) -> VZGenericMachineIdentifier {
    // Retrieve the machine identifier.
    guard let machineIdentifierData = try? Data(contentsOf: URL(fileURLWithPath: machineIdentifierPath)) else {
      fatalError("Failed to retrieve the machine identifier data.")
    }
    
    guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) else {
      fatalError("Failed to create the machine identifier.")
    }
    
    return machineIdentifier
  }
  
  private func createEFIVariableStore(efiVariableStorePath: String) -> VZEFIVariableStore {
    guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efiVariableStorePath)) else {
      fatalError("Failed to create the EFI variable store.")
    }
    
    return efiVariableStore
  }
  
  private func retrieveEFIVariableStore(efiVariableStorePath: String) -> VZEFIVariableStore {
    if !FileManager.default.fileExists(atPath: efiVariableStorePath) {
      fatalError("EFI variable store does not exist.")
    }
    
    return VZEFIVariableStore(url: URL(fileURLWithPath: efiVariableStorePath))
  }
  
  private func createUSBMassStorageDeviceConfiguration() -> VZUSBMassStorageDeviceConfiguration {
    guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: installerISOPath!, readOnly: true) else {
      fatalError("Failed to create installer's disk attachment.")
    }
    
    return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
  }
  
  private func createNetworkDeviceConfiguration() -> VZVirtioNetworkDeviceConfiguration {
    let networkDevice = VZVirtioNetworkDeviceConfiguration()
    networkDevice.attachment = VZNATNetworkDeviceAttachment()
    
    return networkDevice
  }
  
  private func createGraphicsDeviceConfiguration() -> VZVirtioGraphicsDeviceConfiguration {
    let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
    graphicsDevice.scanouts = [
      VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1920, heightInPixels: 1200)
    ]
    
    return graphicsDevice
  }
  
  private func createInputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
    let inputAudioDevice = VZVirtioSoundDeviceConfiguration()
    
    let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
    inputStream.source = VZHostAudioInputStreamSource()
    
    inputAudioDevice.streams = [inputStream]
    return inputAudioDevice
  }
  
  private func createOutputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
    let outputAudioDevice = VZVirtioSoundDeviceConfiguration()
    
    let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
    outputStream.sink = VZHostAudioOutputStreamSink()
    
    outputAudioDevice.streams = [outputStream]
    return outputAudioDevice
  }
  
  private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
    let consoleDevice = VZVirtioConsoleDeviceConfiguration()
    
    let spiceAgentPort = VZVirtioConsolePortConfiguration()
    spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
    
    let spiceAgentAttachment = VZSpiceAgentPortAttachment()
    spiceAgentAttachment.sharesClipboard = true
    spiceAgentPort.attachment = spiceAgentAttachment
    
    consoleDevice.ports[0] = spiceAgentPort
    
    return consoleDevice
  }
  
  private func createAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
    let audioDevice = VZVirtioSoundDeviceConfiguration()
    
    // 입력 스트림 구성
    let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
    inputStream.source = VZHostAudioInputStreamSource()
    
    // 출력 스트림 구성
    let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
    outputStream.sink = VZHostAudioOutputStreamSink()
    
    // 두 스트림을 하나의 장치에 할당
    audioDevice.streams = [inputStream, outputStream]
    
    return audioDevice
  }
  
  // MARK: Create the virtual machine configuration and instantiate the virtual machine.
  
  func createVirtualMachine(_ item : Item) {
    let virtualMachineConfiguration = VZVirtualMachineConfiguration()
    
    virtualMachineConfiguration.cpuCount = computeCPUCount(CPUCount: item.cpuCount)
    virtualMachineConfiguration.memorySize = computeMemorySize(MemorySize: item.memorySize)
    
    let platform = VZGenericPlatformConfiguration()
    let bootloader = VZEFIBootLoader()
    let disksArray = NSMutableArray()
    
    if item.needsInstall {
      // This is a fresh install: Create a new machine identifier and EFI variable store,
      // and configure a USB mass storage device to boot the ISO image.
      platform.machineIdentifier = createAndSaveMachineIdentifier(machineIdentifierPath: item.machineIdentifierPath)
      bootloader.variableStore = createEFIVariableStore(efiVariableStorePath: item.efiVariableStorePath!)
      disksArray.add(createUSBMassStorageDeviceConfiguration())
    } else {
      // The VM is booting from a disk image that already has the OS installed.
      // Retrieve the machine identifier and EFI variable store that were saved to
      // disk during installation.
      platform.machineIdentifier = retrieveMachineIdentifier(machineIdentifierPath: item.machineIdentifierPath)
      bootloader.variableStore = retrieveEFIVariableStore(efiVariableStorePath: item.efiVariableStorePath!)
    }
    
    virtualMachineConfiguration.platform = platform
    virtualMachineConfiguration.bootLoader = bootloader
    
    disksArray.add(createBlockDeviceConfiguration(mainDiskImagePath: item.mainDiskImagePath))
    guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
      fatalError("Invalid disksArray.")
    }
    virtualMachineConfiguration.storageDevices = disks
    
    virtualMachineConfiguration.networkDevices = [createNetworkDeviceConfiguration()]
    virtualMachineConfiguration.graphicsDevices = [createGraphicsDeviceConfiguration()]
    virtualMachineConfiguration.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]
    //virtualMachineConfiguration.audioDevices = [createAudioDeviceConfiguration()]
    
    virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
    virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
    virtualMachineConfiguration.consoleDevices = [createSpiceAgentConsoleDeviceConfiguration()]
    
    try! virtualMachineConfiguration.validate()
    virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
  }
  
  // MARK: Start the virtual machine.
  
  func configureAndStartVirtualMachine(_ item : Item) {
    DispatchQueue.main.async {
      self.createVirtualMachine(item)
      self.virtualMachineView.virtualMachine = self.virtualMachine
      
      if #available(macOS 14.0, *) {
        // Configure the app to automatically respond changes in the display size.
        self.virtualMachineView.automaticallyReconfiguresDisplay = true
      }
      
      self.virtualMachine.delegate = self
      self.virtualMachine.start(completionHandler: { (result) in
        switch result {
        case let .failure(error):
          fatalError("Virtual machine failed to start with error: \(error)")
          
        default:
          print("Virtual machine successfully started.")
        }
      })
    }
  }
  
  func applicationDidFinishLaunching(_ aNotification: Notification, item: Item) {
    NSWindow.allowsAutomaticWindowTabbing = false
    
    NSApp.activate(ignoringOtherApps: true)
        
    // If "GUI Linux VM.bundle" doesn't exist, the sample app tries to create
    // one and install Linux onto an empty disk image from the ISO image,
    // otherwise, it tries to directly boot from the disk image inside
    // the "GUI Linux VM.bundle".
    if !FileManager.default.fileExists(atPath: item.vmBundlePath) {
      item.needsInstall = true
      createVMBundle(vmBundlePath: item.vmBundlePath)
      createMainDiskImage(DiskSize: item.diskSize, mainDiskImagePath: item.mainDiskImagePath)
      
      let openPanel = NSOpenPanel()
      openPanel.canChooseFiles = true
      openPanel.allowsMultipleSelection = false
      openPanel.canChooseDirectories = false
      openPanel.canCreateDirectories = false
      
      openPanel.begin { (result) -> Void in
        if result == .OK {
          self.installerISOPath = openPanel.url!
          self.configureAndStartVirtualMachine(item)
        } else {
          fatalError("ISO file not selected.")
        }
      }
    } else {
      item.needsInstall = false
      configureAndStartVirtualMachine(item)
    }
  }
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
  
  // MARK: VZVirtualMachineDelegate methods.
  
  func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
    print("Virtual machine did stop with error: \(error.localizedDescription)")
    exit(-1)
  }

  func guestDidStop(_ virtualMachine: VZVirtualMachine) {
    print("Guest did stop virtual machine.")
    // VM 상태 저장, 리소스 정리 등
    DispatchQueue.main.async {
      // UI 정리 후 종료
      NSApp.terminate(nil)
    }
  }
  
  func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
    print("Netowrk attachment was disconnected with error: \(error.localizedDescription)")
  }
}
