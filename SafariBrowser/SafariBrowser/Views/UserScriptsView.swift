import SwiftUI
import SwiftData
import SafariBrowserCore

struct UserScriptsView: View {
    @Environment(UserscriptManager.self) private var userscriptManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editingScript: Userscript?

    var body: some View {
        NavigationStack {
            Group {
                if userscriptManager.scripts.isEmpty {
                    BrowserEmptyState(
                        icon: "chevron.left.forwardslash.chevron.right",
                        title: "No Userscripts",
                        message: "Add scripts to customize pages you visit."
                    )
                    .padding()
                } else {
                    List {
                        ForEach(userscriptManager.scripts) { script in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(script.name)
                                        .font(.body.weight(.medium))
                                    Text(script.matchPatterns.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(BrowserTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Toggle("", isOn: binding(for: script))
                                    .labelsHidden()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingScript = script
                            }
                        }
                        .onDelete(perform: deleteScripts)
                    }
                }
            }
            .navigationTitle("Userscripts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingScript = Userscript(name: "New Script", source: "// Your code here\n")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingScript) { script in
                UserScriptEditorView(script: script) { saved in
                    saveScript(saved)
                }
            }
        }
    }

    private func binding(for script: Userscript) -> Binding<Bool> {
        Binding(
            get: { script.isEnabled },
            set: { newValue in
                if let index = userscriptManager.scripts.firstIndex(where: { $0.id == script.id }) {
                    userscriptManager.scripts[index].isEnabled = newValue
                    persistAll()
                }
            }
        )
    }

    private func saveScript(_ script: Userscript) {
        if let index = userscriptManager.scripts.firstIndex(where: { $0.id == script.id }) {
            userscriptManager.scripts[index] = script
        } else {
            userscriptManager.scripts.append(script)
        }
        persistAll()
    }

    private func deleteScripts(at offsets: IndexSet) {
        userscriptManager.scripts.remove(atOffsets: offsets)
        persistAll()
    }

    private func persistAll() {
        let descriptor = FetchDescriptor<StoredUserScript>()
        if let existing = try? modelContext.fetch(descriptor) {
            existing.forEach { modelContext.delete($0) }
        }
        for script in userscriptManager.scripts {
            modelContext.insert(StoredUserScript(from: script))
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .userscriptsDidChange, object: nil)
    }
}

struct UserScriptEditorView: View {
    @State var script: Userscript
    var onSave: (Userscript) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $script.name)
                Picker("Run At", selection: $script.runAt) {
                    Text("Document Start").tag(Userscript.RunAt.documentStart)
                    Text("Document End").tag(Userscript.RunAt.documentEnd)
                }
                Section("Match Patterns (comma-separated)") {
                    TextField("*://*/*", text: Binding(
                        get: { script.matchPatterns.joined(separator: ", ") },
                        set: { script.matchPatterns = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
                Section("Source") {
                    TextEditor(text: $script.source)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("Edit Script")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(script)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
