{{flutter_js}}
{{flutter_build_config}}

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath = build.mainJsPath.split('?')[0] + '?v=0.7.1';
}
_flutter.loader.load();



