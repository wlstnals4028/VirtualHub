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
            Text("CPU: \(item.cpuCount)개 | 메모리: \(formatBytes(item.memorySize))")
              .font(.caption)
              .foregroundColor(.secondary)
            Text("디스크: \(formatBytes(item.diskSize))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 2)
        }
      }
      .navigationTitle("가상 머신")
      .navigationSplitViewColumnWidth(min: 250, ideal: 300)
      .toolbar {
        ToolbarItem {
          Button(action: { showingAddVM = true }) {
            Label("VM 추가", systemImage: "plus")
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
        Text("가상 머신을 선택하세요")
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
        Section(header: Text("기본 설정")) {
          TextField("VM 이름", text: $name)
          
          Picker("운영체제", selection: $isLinux) {
            Text("Linux").tag(true)
            Text("기타").tag(false)
          }
          .pickerStyle(.segmented)
        }
        
        Section(header: Text("하드웨어 설정")) {
          Stepper("CPU 코어: \(cpuCount)개", value: $cpuCount, in: 1...8)
          
          VStack(alignment: .leading) {
            Text("메모리: \(String(format: "%.0f", memorySize))GB")
            Slider(value: $memorySize, in: 1...16, step: 1)
          }
          
          VStack(alignment: .leading) {
            Text("디스크 용량: \(String(format: "%.0f", diskSize))GB")
            Slider(value: $diskSize, in: 10...100, step: 5)
          }
        }
        
        Section(header: Text("저장 위치")) {
          TextField("VM 번들 경로", text: $vmBundlePath)
            .textFieldStyle(.roundedBorder)
        }
      }
      .navigationTitle("새 가상 머신")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("생성") {
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
      print("VM 저장 실패: \(error)")
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
        
        Text(item.isLinux ? "Linux 가상 머신" : "가상 머신")
          .font(.title3)
          .foregroundColor(.secondary)
      }
      
      VStack(alignment: .leading, spacing: 12) {
        Text("하드웨어 구성")
          .font(.headline)
        
        HStack {
          Label("CPU", systemImage: "cpu")
          Spacer()
          Text("\(item.cpuCount)개 코어")
        }
        
        HStack {
          Label("메모리", systemImage: "memorychip")
          Spacer()
          Text(formatBytes(item.memorySize))
        }
        
        HStack {
          Label("디스크", systemImage: "internaldrive")
          Spacer()
          Text(formatBytes(item.diskSize))
        }
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)
      
      VStack(alignment: .leading, spacing: 12) {
        Text("파일 경로")
          .font(.headline)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("VM 번들:")
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
          Text("가상 머신 시작")
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
