import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: ReaderSettings
    var onDismiss: () -> Void
    
    // Local state for the sliders
    @State private var fontSize: Double = 0
    @State private var lineSpacing: Double = 0
    @State private var horizontalPadding: Double = 0
    @State private var isDarkMode: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Display")) {
                    HStack {
                        Text("Font Size")
                        Slider(value: $fontSize, in: 12...24, step: 1)
                            .onChange(of: fontSize) { newValue in
                                settings.fontSize = CGFloat(newValue)
                                settings.save()
                            }
                        Text("\(Int(fontSize))")
                            .frame(width: 30, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Line Spacing")
                        Slider(value: $lineSpacing, in: 1.0...2.0, step: 0.1)
                            .onChange(of: lineSpacing) { newValue in
                                settings.lineSpacing = CGFloat(newValue)
                                settings.save()
                            }
                        Text(String(format: "%.1f", lineSpacing))
                            .frame(width: 30, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Horizontal Padding")
                        Slider(value: $horizontalPadding, in: 10...40, step: 5)
                            .onChange(of: horizontalPadding) { newValue in
                                settings.horizontalPadding = CGFloat(newValue)
                                settings.save()
                            }
                        Text("\(Int(horizontalPadding))")
                            .frame(width: 30, alignment: .trailing)
                    }
                    
                    Toggle("Dark Mode", isOn: $isDarkMode)
                        .onChange(of: isDarkMode) { newValue in
                            settings.darkMode = newValue
                            settings.save()
                        }
                }
                
                Section {
                    Button("Restore Defaults") {
                        // Reset to defaults
                        fontSize = 16
                        lineSpacing = 1.5
                        horizontalPadding = 20
                        isDarkMode = false
                        
                        // Update settings
                        settings.fontSize = 16
                        settings.lineSpacing = 1.5
                        settings.horizontalPadding = 20
                        settings.darkMode = false
                        settings.save()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                onDismiss()
            })
        }
        .onAppear {
            // Initialize local state from settings
            fontSize = Double(settings.fontSize)
            lineSpacing = Double(settings.lineSpacing)
            horizontalPadding = Double(settings.horizontalPadding)
            isDarkMode = settings.darkMode
        }
    }
} 