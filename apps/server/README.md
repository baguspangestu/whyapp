# WhyApp server

NestJS backend for WhyApp with Prisma/SQLite, JWT authentication and
Socket.IO realtime messages.

## Setup

```powershell
Copy-Item .env.example .env
npm install
npm run prisma:generate
npm run prisma:push
npm run prisma:seed
npm run start:dev
```

The API runs at `http://127.0.0.1:3000/api` and Swagger documentation is at
`http://127.0.0.1:3000/api/docs`.

Seed users use password `password123`: `pixel`, `support`, and `ada`.

All endpoints except login and registration require a Bearer token.
