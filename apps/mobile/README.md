# WhyApp mobile

Flutter client for WhyApp. It uses REST for authentication and chat history,
Socket.IO for incoming messages, and stores the access token locally.

## Run

Start the backend first, then run:

```powershell
flutter pub get
flutter run
```

The default API points to the development PC at `http://192.168.2.3:3000`,
so a physical Android device on the same network can connect directly. To
override it for an Android emulator use:

```powershell
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/ --dart-define=SOCKET_URL=http://10.0.2.2:3000
```

`API_URL` must end with `/`.
