import { Controller, Get } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../database/prisma.service';
import { AuthUser } from '../auth/jwt.strategy';

@Controller('users')
export class UsersController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  list(@CurrentUser() authUser: AuthUser) {
    return this.prisma.user.findMany({
      where: { id: { not: authUser.id } },
      orderBy: [{ displayName: 'asc' }, { username: 'asc' }],
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        isOnline: true,
        presenceStatus: true,
        lastSeen: true,
      },
    });
  }

  @Get('me')
  me(@CurrentUser() authUser: AuthUser) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: authUser.id },
      select: { id: true, username: true, displayName: true, avatarUrl: true, isOnline: true, lastSeen: true },
    });
  }
}
