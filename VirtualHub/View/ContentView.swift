//
//  ContentView.swift
//  VirtualHub
//
//  Created by 진수민 on 7/13/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  @State private var showingAddVM = false
  @State private var selectedItem: Item?
  @State private var showingDeleteAlert = false
  @State private var itemToDelete: Item?
  
  var body: some View {
    NavigationSplitView {
      List(items, selection: $selectedItem) { item in
        NavigationLink(value: item) {
          VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
              .font(.headline)
            Text("CPU: \(item.cpuCount)cores | Memory: \(formatBytes(item.memorySize))")
              .font(.caption)
              .foregroundColor(.secondary)
            Text("disk: \(formatBytes(item.diskSize))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 2)
        }
        .contextMenu {
          Button("Delete Virtual Machine", systemImage: "trash", role: .destructive) {
            itemToDelete = item
            showingDeleteAlert = true
          }
        }
      }
      .navigationTitle("Virtual Machines")
      .navigationSplitViewColumnWidth(min: 250, ideal: 300)
      .toolbar {
        ToolbarItem {
          Button(action: {
            showingAddVM = true
            selectedItem = nil
          }) {
            Label("Add Virtual Machine", systemImage: "plus")
          }
        }
      }
      .onDeleteCommand {
        if let selectedItem = selectedItem {
          itemToDelete = selectedItem
          showingDeleteAlert = true
        }
      }
    } detail: {
      if showingAddVM {
        AddVMView(
          modelContext: modelContext,
          onDismiss: {
            showingAddVM = false
          }
        )
      } else if let selectedItem = selectedItem {
        VMDetailView(item: selectedItem)
      } else {
        Text("Select a virtual machine")
          .foregroundColor(.secondary)
      }
    }
    .navigationSplitViewStyle(.balanced)
    .alert("Delete Virtual Machine", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        if let item = itemToDelete {
          deleteVM(item)
        }
      }
    } message: {
      if let item = itemToDelete {
        Text("Are you sure you want to delete '\(item.name)'? This action cannot be undone and will permanently remove all Virtual Machine files.")
      }
    }
  }
  
  private func deleteVM(_ item: Item) {
    let fileManager = FileManager.default
    let bundlePath = item.vmBundlePath
    
    do {
      if fileManager.fileExists(atPath: bundlePath) {
        try fileManager.removeItem(atPath: bundlePath)
        print("Successfully deleted VM bundle: \(bundlePath)")
      } else {
        print("VM bundle not found: \(bundlePath)")
      }
    } catch {
      print("Error deleting VM bundle: \(error.localizedDescription)")
    }
    
    withAnimation {
      modelContext.delete(item)
      
      if selectedItem == item {
        selectedItem = nil
      }
    }
    
    do {
      try modelContext.save()
    } catch {
      print("Error saving context after deletion: \(error.localizedDescription)")
    }
    
    itemToDelete = nil
  }
  
  private func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    return String(format: "%.0fGB", gb)
  }
}


struct AddVMView: View {
  let modelContext: ModelContext
  let onDismiss: () -> Void
  
  @State private var name = ""
  @State private var isLinux = true
  @State private var cpuCount = 2
  @State private var memorySize = 4.0 // GB
  @State private var diskSize = 20.0 // GB
  @State private var vmBundlePath = NSHomeDirectory()
  
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        // 헤더
        HStack {
          VStack(alignment: .leading) {
            Text("New Virtual Machine")
              .font(.largeTitle)
              .fontWeight(.bold)
            Text("Configure your virtual machine settings")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          
          Spacer()
          
          HStack {
            Button("Cancel") {
              onDismiss()
            }
            .buttonStyle(.bordered)
            
            Button("Create") {
              createVM()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty)
          }
        }
        .padding()
        
        Divider()
        
        // 폼 내용
        VStack(spacing: 20) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Basic Settings")
              .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Virtual Machine Name")
                .font(.subheadline)
                .fontWeight(.medium)
              TextField("Enter Virtual Machine name", text: $name)
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Operating System")
                .font(.subheadline)
                .fontWeight(.medium)
              Picker("Operating System", selection: $isLinux) {
                Text("Linux").tag(true)
                Text("MacOS").tag(false)
              }
              .pickerStyle(.segmented)
            }
          }
          .padding()
          .background(Color.gray.opacity(0.05))
          .cornerRadius(10)
          
          VStack(alignment: .leading, spacing: 12) {
            Text("Hardware Settings")
              .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text("CPU Cores")
                  .font(.subheadline)
                  .fontWeight(.medium)
                Spacer()
                Stepper("\(cpuCount)", value: $cpuCount, in: 1...ProcessInfo.processInfo.processorCount)
              }
              
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("Memory")//메모리
                    .font(.subheadline)
                    .fontWeight(.medium)
                  Spacer()
                  Text("\(String(format: "%.0f", memorySize))GB")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                Slider(value: $memorySize, in: 1...Double(ProcessInfo.processInfo.physicalMemory >> 30), step: 1)
              }
              
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("Disk Size")//디스크 용량
                    .font(.subheadline)
                    .fontWeight(.medium)
                  Spacer()
                  Text("\(String(format: "%.0f", diskSize))GB")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                Slider(value: $diskSize, in: 10...200, step: 5)
              }
            }
          }
          .padding()
          .background(Color.gray.opacity(0.05))
          .cornerRadius(10)
          
          VStack(alignment: .leading, spacing: 12) {
            Text("Storage Location")
              .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Virtual Machine Bundle Path")
                .font(.subheadline)
                .fontWeight(.medium)
              TextField("Virtual Machine Bundle Path", text: $vmBundlePath)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            }
          }
          .padding()
          .background(Color.gray.opacity(0.05))
          .cornerRadius(10)
        }
        .padding()
      }
    }
  }
  
  private func createVM() {
    let memoryBytes = UInt64(memorySize * 1024 * 1024 * 1024)
    let diskBytes = UInt64(diskSize * 1024 * 1024 * 1024)
    
    let newItem = Item(
      name: name,
      vmBundlePath: vmBundlePath,
      isLinux: isLinux,
      cpuCount: cpuCount,
      memorySize: memoryBytes,
      diskSize: diskBytes
    )
    
    modelContext.insert(newItem)
    
    do {
      try modelContext.save()
      onDismiss()
    } catch {
      print("Failed to save VM: \(error)")
    }
  }
}


struct VMDetailView: View {
  let item: Item
  @State private var isRunning = false
  @State private var showingDeleteAlert = false
  @Environment(\.modelContext) private var modelContext
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Text(item.name)
          .font(.largeTitle)
          .fontWeight(.bold)
        
        Text(item.isLinux ? "Linux Virtual Machine" : "MacOS Virtual Machine")
          .font(.title3)
          .foregroundColor(.secondary)
      }
      
      VStack(alignment: .leading, spacing: 12) {
        Text("Hardware Configuration")
          .font(.headline)
        
        HStack {
          Label("CPU", systemImage: "cpu")
          Spacer()
          Text("\(item.cpuCount)cores")
        }
        
        HStack {
          Label("Memory", systemImage: "memorychip")
          Spacer()
          Text(formatBytes(item.memorySize))
        }
        
        HStack {
          Label("disk", systemImage: "internaldrive")
          Spacer()
          Text(formatBytes(item.diskSize))
        }
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)
      
      VStack(alignment: .leading, spacing: 12) {
        Text("File Path")
          .font(.headline)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Virtual Machine Bundle:")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(item.vmBundlePath)
            .font(.system(.caption, design: .monospaced))
        }
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)
      
      Spacer()
      
      Button(action: {
        startVM()
      }) {
        HStack {
          Image(systemName: "play.fill")
          Text("Start Virtual Machine")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
      }
      .disabled(isRunning)
      
      Button(action: {
        showingDeleteAlert = true
      }) {
        HStack {
          Image(systemName: "trash")
          Text("Delete Virtual Machine")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.red)
        .foregroundColor(.white)
        .cornerRadius(10)
      }
      .disabled(isRunning)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .alert("Delete Virtual Machine", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        deleteVM()
      }
    } message: {
      Text("Are you sure you want to delete '\(item.name)'? This action cannot be undone and will permanently remove all Virtual Machine files.")
    }
  }
  
  private func deleteVM() {
    let fileManager = FileManager.default
    let bundlePath = item.vmBundlePath
    
    do {
      if fileManager.fileExists(atPath: bundlePath) {
        try fileManager.removeItem(atPath: bundlePath)
        print("Successfully deleted VM bundle: \(bundlePath)")
      }
    } catch {
      print("Error deleting VM bundle: \(error.localizedDescription)")
    }
    
    // 데이터베이스에서 삭제
    modelContext.delete(item)
    
    do {
      try modelContext.save()
    } catch {
      print("Error saving context after deletion: \(error.localizedDescription)")
    }
    
    // 선택 해제 알림
    NotificationCenter.default.post(name: .selectionChanged, object: nil)
  }
  
  private func startVM() {
    isRunning = true
    VMWindowManager.shared.openVMWindow(for: item)
  }
  
  private func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    return String(format: "%.0fGB", gb)
  }
}

extension Notification.Name {
  static let selectionChanged = Notification.Name("selectionChanged")
}

extension FileManager {
  func safeRemoveItem(atPath path: String) -> Bool {
    guard fileExists(atPath: path) else {
      print("File does not exist: \(path)")
      return true
    }
    
    do {
      try removeItem(atPath: path)
      print("Successfully removed: \(path)")
      return true
    } catch {
      print("Failed to remove item at \(path): \(error.localizedDescription)")
      return false
    }
  }
}

