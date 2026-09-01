import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';

@WebSocketGateway({ cors: { origin: true } })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly connections = new Map<string, number>();
  private readonly idleTimers = new Map<string, NodeJS.Timeout>();
  private readonly idleAfterMs = 3 * 60 * 1000;
  constructor(private readonly jwt: JwtService, private readonly chat: ChatService) {}

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token as string;
      client.data.user = this.jwt.verify(token);
      const userId = client.data.user.sub as string;
      await client.join(`user:${userId}`);
      this.connections.set(userId, (this.connections.get(userId) ?? 0) + 1);
      await this.markActive(userId);
    } catch { client.disconnect(); }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data.user?.sub as string | undefined;
    if (!userId) return;
    const remaining = Math.max((this.connections.get(userId) ?? 1) - 1, 0);
    if (remaining == 0) {
      this.connections.delete(userId);
      const timer = this.idleTimers.get(userId);
      if (timer) clearTimeout(timer);
      this.idleTimers.delete(userId);
      await this.publishPresence(userId, 'OFFLINE');
    } else {
      this.connections.set(userId, remaining);
    }
  }

  @SubscribeMessage('presence:activity')
  async activity(@ConnectedSocket() client: Socket) {
    const userId = client.data.user?.sub as string | undefined;
    if (userId) await this.markActive(userId);
  }

  private async markActive(userId: string) {
    const existing = this.idleTimers.get(userId);
    if (existing) clearTimeout(existing);
    await this.publishPresence(userId, 'ONLINE');
    this.idleTimers.set(
      userId,
      setTimeout(() => {
        void this.publishPresence(userId, 'IDLE');
      }, this.idleAfterMs),
    );
  }

  private async publishPresence(
    userId: string,
    status: 'ONLINE' | 'IDLE' | 'OFFLINE',
  ) {
    await this.chat.setPresence(userId, status);
    this.server.emit('presence:updated', {
      userId,
      status,
      isOnline: status !== 'OFFLINE',
      isIdle: status === 'IDLE',
      lastSeen: new Date().toISOString(),
    });
  }

  @SubscribeMessage('conversation:join')
  async join(@ConnectedSocket() client: Socket, @MessageBody() conversationId: string) {
    if (await this.chat.isMember(client.data.user.sub as string, conversationId)) {
      await client.join(`conversation:${conversationId}`);
    }
  }

  publishMessage(conversationId: string, memberIds: string[], message: unknown) {
    for (const userId of memberIds) {
      this.server.to(`user:${userId}`).emit('message:created', message);
    }
  }

  publishRead(memberIds: string[], receipt: unknown) {
    for (const userId of memberIds) {
      this.server.to(`user:${userId}`).emit('message:read', receipt);
    }
  }
}
