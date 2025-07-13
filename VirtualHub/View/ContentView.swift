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
  
  var body: some View {
    NavigationSplitView {
      List(items, selection: $selectedItem) { item in
        NavigationLink(value: item) {
          VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
              .font(.headline)
            Text("CPU: \(item.cpuCount)cores | memory: \(formatBytes(item.memorySize))")//개 | 메모리
              .font(.caption)
              .foregroundColor(.secondary)
            Text("disk: \(formatBytes(item.diskSize))")//디스크
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 2)
        }
      }
      .navigationTitle("Virtual Machines")//가상 머신
      .navigationSplitViewColumnWidth(min: 250, ideal: 300)
      .toolbar {
        ToolbarItem {
          Button(action: { showingAddVM = true }) {
            Label("Add VM", systemImage: "plus")//VM 추가
          }
        }
      }
      .sheet(isPresented: $showingAddVM) {
        AddVMView(modelContext: modelContext)
      }
    } detail: {
      if let selectedItem = selectedItem {
        VMDetailView(item: selectedItem)
      } else {
        Text("Select a virtual machine")//가상 머신을 선택하세요
          .foregroundColor(.secondary)
      }
    }
    .navigationSplitViewStyle(.balanced)
    .onDeleteCommand {
      // 삭제 명령 처리
      if let selectedItem = selectedItem {
        if let index = items.firstIndex(of: selectedItem) {
          deleteItems(offsets: IndexSet([index]))
        }
      }
    }
  }
  
  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(items[index])
      }
    }
  }
  
  private func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    return String(format: "%.0fGB", gb)
  }
}


struct AddVMView: View {
  let modelContext: ModelContext
  @Environment(\.dismiss) private var dismiss
  
  @State private var name = ""
  @State private var isLinux = true
  @State private var cpuCount = 2
  @State private var memorySize = 4.0 // GB
  @State private var diskSize = 20.0 // GB
  @State private var vmBundlePath = NSHomeDirectory()
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Basic Settings")) {//기본 설정
          TextField("VM Name", text: $name)//VM 이름
          
          Picker("Operating System", selection: $isLinux) {//운영체제
            Text("Linux").tag(true)
            Text("MacOS").tag(false)
          }
          .pickerStyle(.segmented)
        }
        
        Section(header: Text("Hardware Settings")) {//하드웨어 설정
          Stepper("CPUCores: \(cpuCount)", value: $cpuCount, in: 1...8)//CPU 코어
          
          VStack(alignment: .leading) {
            Text("memorySize: \(String(format: "%.0f", memorySize))GB")//메모리
            Slider(value: $memorySize, in: 1...16, step: 1)
          }
          
          VStack(alignment: .leading) {
            Text("diskSize: \(String(format: "%.0f", diskSize))GB")//디스크 용량
            Slider(value: $diskSize, in: 10...100, step: 5)
          }
        }
        
        Section(header: Text("Storage Location")) {//저장 위치
          TextField("VM Bundle Path", text: $vmBundlePath)//VM 번들 경로
            .textFieldStyle(.roundedBorder)
        }
      }
      .navigationTitle("New Virtual Machine")//새 가상 머신
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {//취소
            dismiss()
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {//생성
            createVM()
          }
          .disabled(name.isEmpty)
        }
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
    } catch {
      print("Failed to save VM: \(error)")//VM 저장 실패
    }
    
    dismiss()
  }
}

struct VMDetailView: View {
  let item: Item
  @State private var isRunning = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Text(item.name)
          .font(.largeTitle)
          .fontWeight(.bold)
        
        Text(item.isLinux ? "Linux Virtual Machine" : "MacOS Virtual Machine")//"Linux 가상 머신" : "MacOS 가상 머신"
          .font(.title3)
          .foregroundColor(.secondary)
      }
      
      VStack(alignment: .leading, spacing: 12) {
        Text("Hardware Configuration")//하드웨어 구성
          .font(.headline)
        
        HStack {
          Label("CPU", systemImage: "cpu")
          Spacer()
          Text("\(item.cpuCount)cores")//개 코어
        }
        
        HStack {
          Label("memory", systemImage: "memorychip")//메모리
          Spacer()
          Text(formatBytes(item.memorySize))
        }
        
        HStack {
          Label("disk", systemImage: "internaldrive")//디스크
          Spacer()
          Text(formatBytes(item.diskSize))
        }
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)
      
      VStack(alignment: .leading, spacing: 12) {
        Text("File Path")//파일 경로
          .font(.headline)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("VM Bundle:")//VM 번들
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
          Text("Start Virtual Machine")//가상 머신 시작
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
      }
      .disabled(isRunning)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
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
