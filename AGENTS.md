# Synergy - Anonymous Social Network

## Tech Stack
- **Flutter** (iOS/Android)
- **BLoC** - state management (required)
- **Freezed** - immutable data classes (required)
- **Clean Architecture** - domain/data/presentation layers

## Architecture Rules
- 1 widget per file
- Separate widgets = separate files (not inner classes)
- Layers: `lib/core/` (shared), `lib/features/` (features)
- Each feature: `data/`, `domain/`, `presentation/` subdirs

## Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
Run after creating/modifying Freezed classes.

## Verification Commands
```bash
flutter analyze    # lint + typecheck
flutter test       # unit tests
```

## Project Structure
```
lib/
├── core/           # shared utilities, constants, errors
├── features/       # feature modules (auth, feed, profile, chat)
├── main.dart
```

## Security Requirements
- End-to-end encryption for all user data
- Anonymous by default (no real names, no phone/email)
- Secure storage using flutter_secure_storage