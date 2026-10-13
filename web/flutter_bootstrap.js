{{flutter_js}}
{{flutter_build_config}}

// Starts Reserve. Same as Flutter's default bootstrap, except that:
// - CanvasKit (the WebAssembly rendering engine, ~6 MB) loads from this
//   folder when the web server sends .wasm files as "application/wasm",
//   which browsers insist on, and from Google's CDN when it doesn't. So the
//   upload is self-contained on a well-configured server and still works on
//   one that isn't;
// - no service worker is registered, so nothing is cached across uploads and
//   a new build is picked up on the next visit (handy for a demo site);
// - it reports progress to the loading screen in index.html, and shows a
//   message there if loading is slow or fails.
(function () {
  var loader = document.getElementById('reserve-loader');
  function stage(name) {
    if (loader) loader.setAttribute('data-stage', name);
  }
  function fail(error) {
    console.error('Reserve failed to start:', error);
    if (loader) loader.classList.add('rl-failed');
  }

  var slow = setTimeout(function () {
    if (loader) loader.classList.add('rl-slow');
  }, 15000);
  window.addEventListener('flutter-first-frame', function () {
    clearTimeout(slow);
  }, { once: true });

  // Resolves to the local CanvasKit folder if this server can serve it, else
  // null (use the CDN). fetch() resolves the path against <base href>.
  function localCanvasKit() {
    return fetch('canvaskit/canvaskit.wasm', { method: 'HEAD', cache: 'no-store' })
      .then(function (response) {
        var type = (response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
        return response.ok && type === 'application/wasm' ? 'canvaskit/' : null;
      })
      .catch(function () { return null; });
  }

  stage('script');
  localCanvasKit()
    .then(function (canvasKitBaseUrl) {
      var config = {};
      if (canvasKitBaseUrl) config.canvasKitBaseUrl = canvasKitBaseUrl;
      console.info('Reserve: CanvasKit from ' + (canvasKitBaseUrl ? 'this site' : 'the Flutter CDN'));
      return _flutter.loader.load({
        config: config,
        onEntrypointLoaded: async function (engineInitializer) {
          try {
            stage('engine');
            var appRunner = await engineInitializer.initializeEngine(config);
            stage('app');
            await appRunner.runApp();
          } catch (error) {
            fail(error);
          }
        },
      });
    })
    .catch(fail);
})();
