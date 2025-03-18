import SwiftUI
import AppKit

// MARK: - Content View
struct ContentView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var focusedAction: EventService.AppleEventType? = .sleepComputer // Default focus
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 15) {
            // Header
            VStack(spacing: 6) {
                Text("System Control")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                
                Text("Select an action to perform")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 15)
            
            // Action Buttons Grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(EventService.AppleEventType.allCases.sorted(by: { $0.tabOrder < $1.tabOrder })) { action in
                    ActionCardButton(
                        action: action,
                        isDefault: action == .sleepComputer,
                        isFocused: focusedAction == action,
                        onTap: { performAction(action) },
                        onFocus: { focusedAction = action }
                    )
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
            
            Spacer()
            
            // Cancel Button
            Button(action: {
                NSApplication.closeCurrentWindowAndTerminate()
            }) {
                HStack {
                    Text("Cancel")
                    Spacer()
                    Text("⎋")
                        .foregroundColor(.secondary)
                }
                .frame(width: 150)
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)
            .buttonStyle(.bordered)
            .padding(.bottom, 15)
        }
        .padding()
        .frame(width: 400, height: 400)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // Set initial focus to Sleep button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedAction = .sleepComputer
            }
        }
        .onKeyPress(.return) { // Handle Enter key
            if let action = focusedAction {
                performAction(action)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.tab) { // Handle Tab key
            handleTabKey()
            return .handled
        }
        .onKeyPress(.rightArrow) { // Handle right arrow key
            handleRightArrowKey()
            return .handled
        }
        .onKeyPress(.leftArrow) { // Handle left arrow key
            handleLeftArrowKey()
            return .handled
        }
        .onKeyPress(.upArrow) { // Handle up arrow key
            handleUpArrowKey()
            return .handled
        }
        .onKeyPress(.downArrow) { // Handle down arrow key
            handleDownArrowKey()
            return .handled
        }
    }
    
    private func performAction(_ action: EventService.AppleEventType) {
        do {
            // Close the window first for better UX
            NSApplication.closeCurrentWindowAndTerminate()
            
            // Then perform the action
            try EventService.send(event: action)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func handleTabKey() {
        let sortedActions = EventService.AppleEventType.allCases.sorted(by: { $0.tabOrder < $1.tabOrder })
        
        if let currentFocus = focusedAction,
           let currentIndex = sortedActions.firstIndex(of: currentFocus) {
            let nextIndex = (currentIndex + 1) % sortedActions.count
            focusedAction = sortedActions[nextIndex]
        } else {
            focusedAction = sortedActions.first
        }
    }
    
    private func handleRightArrowKey() {
        if focusedAction == .sleepComputer {
            focusedAction = .restartComputer
        } else if focusedAction == .shutdownComputer {
            focusedAction = .logoutUser
        }
    }
    
    private func handleLeftArrowKey() {
        if focusedAction == .restartComputer {
            focusedAction = .sleepComputer
        } else if focusedAction == .logoutUser {
            focusedAction = .shutdownComputer
        }
    }
    
    private func handleUpArrowKey() {
        if focusedAction == .shutdownComputer {
            focusedAction = .sleepComputer
        } else if focusedAction == .logoutUser {
            focusedAction = .restartComputer
        }
    }
    
    private func handleDownArrowKey() {
        if focusedAction == .sleepComputer {
            focusedAction = .shutdownComputer
        } else if focusedAction == .restartComputer {
            focusedAction = .logoutUser
        }
    }
}

// MARK: - Action Card Button
struct ActionCardButton: View {
    let action: EventService.AppleEventType
    let isDefault: Bool
    let isFocused: Bool
    let onTap: () -> Void
    let onFocus: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: action.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(action.color)
                
                Text(action.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("⌘\(action.shortcut.uppercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFocused ? action.color : Color.clear,
                                   lineWidth: isFocused ? 3 : 2)
                    )
                    .shadow(color: (isHovering || isFocused) ? Color.black.opacity(0.2) : Color.clear, radius: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut(KeyEquivalent(Character(action.shortcut)))
        .focusable(true)
        .focusEffectDisabled() // Disable the default focus ring
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    onFocus()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .accessibility(label: Text(action.displayName))
        .accessibility(hint: Text("Press Enter to select"))
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 400, height: 500)
    }
}
