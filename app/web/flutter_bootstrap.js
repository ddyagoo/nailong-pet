// Flutter 默认会从 gstatic CDN 拉 CanvasKit，网络受限时整个应用卡在启动页。
// 这里强制使用构建产物自带的 canvaskit/。
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
