import SwiftUI
import ServiceManagement

// Valeur par défaut pour le chemin DB, accessible hors MainActor.
// Même logique que StatsModel.defaultDBPath : retourne le premier chemin existant.
private func defaultDBPathValue() -> String {
    let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first
    let candidates = [
        appSupport?.appendingPathComponent("macrtk/tracking.db").path,
        (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
            .appendingPathComponent(".local/share/macrtk/tracking.db")
    ].compactMap { $0 }
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
        ?? candidates.last ?? ""
}

struct SettingsView: View {

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("pollingInterval") private var pollingInterval = 30.0
    @AppStorage("dbPath") private var dbPath = defaultDBPathValue()

    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("Général") {
                Toggle("Démarrer au login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }

                if let error = loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Surveillance") {
                Picker("Intervalle de polling", selection: $pollingInterval) {
                    Text("5 secondes").tag(5.0)
                    Text("30 secondes").tag(30.0)
                    Text("60 secondes").tag(60.0)
                }
                .pickerStyle(.menu)
                Text("Prend effet au prochain lancement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Base de données") {
                TextField("Chemin de la DB", text: $dbPath)
                    .font(.system(.caption, design: .monospaced))
                Button("Réinitialiser") {
                    dbPath = defaultDBPathValue()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Prend effet au prochain lancement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Quitter RTKMenuBar") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 350)
        .navigationTitle("Préférences")
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                // unregister peut throw si pas enregistrée — ignorer
                try? SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch let nsError as NSError where nsError.domain == "SMAppServiceErrorDomain" {
            // Code 1 = already registered (idempotent), code 3 = not found (hors /Applications)
            switch nsError.code {
            case 1:
                loginItemError = nil  // Déjà enregistré — idempotent
            case 3:
                loginItemError = "L'app doit être dans /Applications pour activer le démarrage au login"
                launchAtLogin = !enabled
            default:
                loginItemError = "Erreur login item : \(nsError.localizedDescription)"
                launchAtLogin = !enabled
            }
        } catch {
            loginItemError = "Erreur inattendue : \(error.localizedDescription)"
            launchAtLogin = !enabled
        }
    }
}
