import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaBetterSqlite3 } from '@prisma/adapter-better-sqlite3';
import { PrismaClient } from '../../generated/prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    const adapter = new PrismaBetterSqlite3({
      url: process.env.DATABASE_URL ?? 'file:./prisma/dev.db',
    });
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
    // Presence is ephemeral. After a server restart there are no live sockets.
    await this.user.updateMany({
      data: { isOnline: false, presenceStatus: 'OFFLINE' },
    });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
