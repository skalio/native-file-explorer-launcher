# native_file_explorer_launcher example

Pick a file, then show it in Finder or Explorer, open it, or open it with
one of the apps the system suggests.

```bash
flutter run -d macos   # or -d windows
```

The integration tests in `integration_test/` call the real platform side:

```bash
flutter test integration_test -d macos
```
