import FlutterMacOS
import Foundation

// Импортируем наш плагин
import endoscopy_tool

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  // Зарегистрируй здесь другие плагины, если есть
  CameraRecorder.register(with: registry.registrar(forPlugin: "CameraRecorder"))
}
