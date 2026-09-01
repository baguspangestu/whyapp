# WhyApp

WhyApp is maintained as a monorepo so changes to the mobile client and its API
can be reviewed and released together while each application remains independently
buildable and deployable.

## Demo

[Watch the WhyApp demo](./WhyApp.mp4)

## Repository layout

```text
.
├── apps/
│   ├── mobile/   # Flutter client
│   └── server/   # NestJS API and WebSocket server
├── .editorconfig
├── .gitignore
├── WhyApp.mp4 # Product demo
└── README.md
```

Each application owns its dependencies, configuration, tests, and build output.
Do not place application-specific source code at the repository root.

## Mobile app

Requirements: Flutter SDK compatible with `apps/mobile/pubspec.yaml`.

```powershell
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Override the API endpoints at build or run time when needed:

```powershell
flutter run --dart-define=API_URL=http://localhost:3000/api/ --dart-define=SOCKET_URL=http://localhost:3000
```

## Server

Requirements: Node.js and npm. Copy the example environment file before running
the server; never commit the resulting `.env` file.

```powershell
cd apps/server
Copy-Item .env.example .env
npm ci
npx prisma generate
npx prisma db push
npm run start:dev
```

## Development conventions

- Keep domain and feature logic inside the application that owns it.
- Change the server contract and its mobile consumer in the same pull request.
- Keep secrets in local `.env` files or deployment secret stores.
- Run the checks for every affected application before merging.
- Use focused commits; generated build output and dependency folders stay untracked.
