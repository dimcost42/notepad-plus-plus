#ifndef NPP_MAC_PLUGIN_API_H
#define NPP_MAC_PLUGIN_API_H

#ifdef __cplusplus
extern "C" {
#endif

#define NPPMAC_PLUGIN_API_VERSION 1

typedef struct NppMacPluginContext {
    void *app_controller;
} NppMacPluginContext;

// Optional. Return NPPMAC_PLUGIN_API_VERSION for explicit compatibility.
int nppmac_plugin_api_version(void);

// Optional. Called after plugin load.
void nppmac_plugin_init(void *context);

// Optional. Called before plugin unload.
void nppmac_plugin_deinit(void *context);

// Optional. Display name in Plugins menu.
const char *nppmac_plugin_name(void);

// Optional command model (preferred over legacy single-run entrypoint).
int nppmac_plugin_command_count(void);
const char *nppmac_plugin_command_name(int index);
const char *nppmac_plugin_command_id(int index);
void nppmac_plugin_run_command(int index, void *context);

// Optional legacy entrypoint. Used when command model is not exported.
void nppmac_plugin_run(void *context);

#ifdef __cplusplus
}
#endif

#endif
