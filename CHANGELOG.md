# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Performance improvements
- Additional features based on community feedback

## [1.2.0] - 2026-11-11

### Added
- AI alert briefing: when Vision flags a dashboard, a short note on what looks wrong and what to check first,
  with a deterministic built-in fallback and output validation (length, plain text, no invented numbers).
- Settings → AI tab (NovaAISettingsView): on/off, backend + model pickers, editable URLs, Keychain-only keys,
  test connection. AI status indicator in the controls bar and next to each briefing.
- 26 AI tests (security, performance, retry, unit, integration, functional, frame).

### Changed
- AI: migrated to NovaAIKit 1.0.0 (auto failover across Ollama, MLX, TinyLLM, TinyChat, OpenWebUI, Nova Gateway,
  OpenRouter, OpenAI; timeouts, retries, https-only keys under com.jkoch.dashboardscreensaver.*).

### Removed
- The app's own AIBackendManager / AIBackendStatusMenu, and the Google Cloud, Azure, AWS and IBM Watson backends.

### Security
- One-time migration moves a plaintext OpenAI key out of UserDefaults into the Keychain and deletes leftover
  Google/Azure/AWS/IBM secrets (UserDefaults and the old com.jordankoch.DashboardScreensaver Keychain service).

## [1.1.0] - 2026-03-01

### Added
- macOS widget (small, medium, large) via WidgetKit with App Group data sync.

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/DashboardScreensaver/releases).*
