# Synergy 🔒

Red social **anónima** con **cifrado de extremo a extremo** y enfoque en privacidad, desarrollada en **Flutter** para iOS y Android.

Los usuarios participan sin nombre real, teléfono ni correo: la identidad es anónima por defecto y los datos se cifran en el dispositivo.

## ✨ Módulos

| Módulo | Qué hace |
|---|---|
| `auth` | Registro e inicio de sesión anónimo con JWT y almacenamiento seguro |
| `community` | Comunidades y publicaciones globales |
| `content` | Feed y publicaciones |
| `profile` | Perfil anónimo del usuario |
| `payments` | Pagos dentro de la app |
| `wallet` | Billetera Web3 (Reown AppKit + web3dart) |

## 🛠️ Stack

- **Flutter / Dart**
- **BLoC** para manejo de estado
- **Freezed** + `json_annotation` para modelos inmutables
- **Clean Architecture**: capas `data`, `domain` y `presentation` por módulo
- **go_router** para navegación
- **cryptography** para el cifrado de extremo a extremo
- **flutter_secure_storage** y **Hive** para almacenamiento local seguro
- **Reown AppKit** y **web3dart** para la billetera

## 📁 Estructura

```
lib/
├── core/       # utilidades compartidas, red, errores, almacenamiento seguro
├── features/   # auth, community, content, payments, profile, wallet
└── main.dart
test/           # pruebas unitarias y de integración por módulo
```

## 🚀 Cómo correrlo

```bash
cp .env.example .env          # configura las variables
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

Pruebas y análisis:

```bash
flutter analyze
flutter test
```

---

Desarrollado por [Carlos Alfaro](https://carlosalfaro.dev).
