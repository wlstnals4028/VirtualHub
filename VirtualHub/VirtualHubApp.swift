//
//  VirtualHubApp.swift
//  VirtualHub
//
//  Created by 진수민 on 7/13/25.
//

import SwiftUI
import SwiftData
import AppKit
import Virtualization

@main
struct VirtualHubApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Item.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    
    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Virtual Machine") {
          // 새 VM 생성 창 열기
        }
        .keyboardShortcut("n", modifiers: .command)
      }
    }
  }
}

// VM 창 관리를 위한 클래스
class VMWindowManager: ObservableObject {
  static let shared = VMWindowManager()
  private var vmWindows: [UUID: NSWindow] = [:]
  
  private init() {}
  
  func openVMWindow(for item: Item) {
    // 이미 열린 창이 있는지 확인
    if let existingWindow = vmWindows[item.id] {
      existingWindow.makeKeyAndOrderFront(nil)
      return
    }
    
    // 새 창 생성
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 1920, height: 1200),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    
    window.title = item.name
    window.minSize = NSSize(width: 800, height: 600)
    
    // VZVirtualMachineView를 포함하는 뷰 컨트롤러 생성
    let vmViewController = VMViewController(item: item)
    window.contentViewController = vmViewController
    
    // 창 닫기 시 정리
    window.delegate = WindowDelegate { [weak self] in
      self?.vmWindows.removeValue(forKey: item.id)
    }
    
    vmWindows[item.id] = window
    window.makeKeyAndOrderFront(nil)
    
    // AppDelegate를 통해 VM 시작
    vmViewController.startVM()
  }
}

// 창 델리게이트
class WindowDelegate: NSObject, NSWindowDelegate {
  private let onClose: () -> Void
  
  init(onClose: @escaping () -> Void) {
    self.onClose = onClose
  }
  
  func windowWillClose(_ notification: Notification) {
    onClose()
  }
}

// VM 뷰 컨트롤러
class VMViewController: NSViewController {
  private let item: Item
  private var appDelegate: AppDelegate?
  private var vmView: VZVirtualMachineView?
  
  init(item: Item) {
    self.item = item
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func loadView() {
    view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.black.cgColor
    
    // VZVirtualMachineView 생성 및 추가
    vmView = VZVirtualMachineView()
    guard let vmView = vmView else { return }
    
    vmView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(vmView)
    
    NSLayoutConstraint.activate([
      vmView.topAnchor.constraint(equalTo: view.topAnchor),
      vmView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      vmView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      vmView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
  
  func startVM() {
    appDelegate = AppDelegate()
    appDelegate?.virtualMachineView = vmView
    
    // VM 시작
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.appDelegate?.applicationDidFinishLaunching(
        Notification(name: .init("VMStart")),
        item: self.item
      )
    }
  }
  
  override func viewWillDisappear() {
    super.viewWillDisappear()
    // VM 정리 작업
    if let vm = appDelegate?.virtualMachine {
      if vm.state == .running {
        vm.stop {_ in
          print("VM stopped successfully")
        }
      }
    }
  }
}
