// PresetsView.swift
// 3CSynthIOS
//
// Preset browser presented as a modal sheet.
// Supports browsing factory presets, saving user presets, and loading.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - PresetsView

struct PresetsView: View {

    @ObservedObject var presetManager: PresetManager
    var parameters: SynthParameters

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: PresetCategory? = nil
    @State private var showSaveAlert = false
    @State private var newPresetName = ""
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.synthBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category filter chips
                    categoryStrip

                    // Preset list
                    List {
                        if !filteredFactory.isEmpty {
                            Section("Factory") {
                                ForEach(filteredFactory) { preset in
                                    PresetRow(preset: preset) {
                                        parameters.apply(preset)
                                        dismiss()
                                    }
                                }
                            }
                            .listRowBackground(Color.synthSurface)
                        }

                        if !filteredUser.isEmpty {
                            Section("My Presets") {
                                ForEach(filteredUser) { preset in
                                    PresetRow(preset: preset) {
                                        parameters.apply(preset)
                                        dismiss()
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            try? presetManager.delete(preset: preset)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listRowBackground(Color.synthSurface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.synthSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.synthAccent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPresetName = ""
                        showSaveAlert = true
                    } label: {
                        Label("Save", systemImage: "plus.circle")
                    }
                    .foregroundStyle(.synthAccent)
                }
            }
            .searchable(text: $searchText, prompt: "Search presets")
            .alert("Save Preset", isPresented: $showSaveAlert) {
                TextField("Name", text: $newPresetName)
                Button("Save") {
                    let preset = parameters.makePreset(name: newPresetName.isEmpty ? "New Preset" : newPresetName)
                    try? presetManager.save(preset: preset)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Filtered Lists

    private var filteredFactory: [Preset] {
        filter(presetManager.factoryPresets)
    }

    private var filteredUser: [Preset] {
        filter(presetManager.userPresets)
    }

    private func filter(_ presets: [Preset]) -> [Preset] {
        presets.filter { preset in
            let categoryMatch = selectedCategory == nil || preset.category == selectedCategory
            let searchMatch   = searchText.isEmpty || preset.name.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && searchMatch
        }
    }

    // MARK: Category Strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "All",
                             isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(PresetCategory.allCases, id: \.self) { cat in
                    CategoryChip(label: cat.rawValue,
                                 isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.synthSurface)
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.synthCaption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .synthBackground : .synthSecondaryLabel)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.synthAccent : Color.synthBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.synthAccent.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - PresetRow

private struct PresetRow: View {
    let preset: Preset
    let onLoad: () -> Void

    var body: some View {
        Button(action: onLoad) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body)
                        .foregroundStyle(.white)
                    Text(preset.category.rawValue)
                        .font(.synthCaption)
                        .foregroundStyle(.synthSecondaryLabel)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.synthCaption)
                    .foregroundStyle(.synthSecondaryLabel)
            }
        }
    }
}

// MARK: - PresetManager ObservableObject Bridge

/// Thin wrapper so PresetsView can use @ObservedObject on the `@Observable` PresetManager.
extension PresetManager: ObservableObject {}
