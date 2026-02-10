{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
    serviceWorkerSettings: {
        serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function(engineInitializer) {
        // Initialize the Flutter engine with asset base
        let appRunner = await engineInitializer.initializeEngine({
            useColorEmoji: true,
            assetBase: "/",
        });
        // Run the app
        await appRunner.runApp();
    }
});
