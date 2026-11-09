{{flutter_js}}
{{flutter_build_config}}

// Same as Flutter's default start-up, but removes the loading screen from
// index.html once the app is ready to draw.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loading = document.getElementById('loading');
    if (loading) {
      loading.classList.add('done');
      setTimeout(function () { loading.remove(); }, 300);
    }
  },
});
