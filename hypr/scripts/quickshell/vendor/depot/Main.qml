//@ pragma UseQApplication

import Quickshell

// Standalone entry point. Vendored into another shell, import the directory
// and instantiate DepotHost directly instead.
ShellRoot {
    DepotHost {
        openOnStart: true
        quitOnClose: true
    }
}
