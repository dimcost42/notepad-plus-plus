# macOS Plugin Scaffold

The app currently supports a lightweight plugin scaffold:

- Search locations:
  - `macos/plugins/*.dylib`
  - `~/.nppmac/plugins/*.dylib`
- Expected exports are documented in `macos/include/NppMacPluginAPI.h`.
- Loaded plugins appear under the `Plugins` menu.
- Plugins can expose either:
  - legacy single entrypoint: `nppmac_plugin_run`, or
  - command model: `nppmac_plugin_command_count` + `nppmac_plugin_command_name` + `nppmac_plugin_run_command`.

## Minimal plugin example

```c
#include "NppMacPluginAPI.h"

const char *nppmac_plugin_name(void) {
    return "SamplePlugin";
}

int nppmac_plugin_api_version(void) {
    return NPPMAC_PLUGIN_API_VERSION;
}

int nppmac_plugin_command_count(void) {
    return 1;
}

const char *nppmac_plugin_command_name(int index) {
    (void)index;
    return "Do Sample Action";
}

void nppmac_plugin_run_command(int index, void *context) {
    (void)index;
    (void)context;
    // Add behavior here.
}
```

## Build example

```bash
clang -dynamiclib -fPIC sample_plugin.c -o sample_plugin.dylib
```

Copy the resulting `.dylib` into `macos/plugins/` and use `Plugins -> Reload Plugins`.
