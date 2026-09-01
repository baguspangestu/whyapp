import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';

const messageInclude = { sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } } } as const;
const publicUser = { id: true, username: true, displayName: true, avatarUrl: true, isOnline: true, presenceStatus: true, lastSeen: true } as const;

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  async conversations(userId: string) {
    const rows = await this.prisma.conversation.findMany({
      where: { members: { some: { userId } } },
      include: {
        members: { include: { user: { select: publicUser } } },
        messages: { where: { deletedAt: null }, orderBy: { createdAt: 'desc' }, take: 1, include: messageInclude },
      },
      orderBy: [{ lastMessageAt: 'desc' }, { updatedAt: 'desc' }],
    });
    return Promise.all(rows.map(async (conversation) => {
      const membership = conversation.members.find(
        (member) => member.userId === userId,
      );
      const unreadCount = await this.prisma.message.count({
        where: {
          conversationId: conversation.id,
          senderId: { not: userId },
          deletedAt: null,
          ...(membership ? { createdAt: { gt: membership.lastReadAt } } : {}),
        },
      });
      return this.toConversation(conversation, userId, unreadCount);
    }));
  }

  async createConversation(userId: string, dto: CreateConversationDto) {
    const memberIds = [...new Set([userId, ...dto.memberIds])];
    const users = await this.prisma.user.count({ where: { id: { in: memberIds } } });
    if (users !== memberIds.length) throw new NotFoundException('One or more users do not exist');

    if (memberIds.length === 2 && !dto.name) {
      const existing = await this.prisma.conversation.findFirst({
        where: { type: 'DIRECT', AND: memberIds.map((id) => ({ members: { some: { userId: id } } })) },
        include: { members: { include: { user: { select: publicUser } } }, messages: { take: 1, orderBy: { createdAt: 'desc' }, include: messageInclude } },
      });
      if (existing && existing.members.length === 2) return this.toConversation(existing, userId);
    }

    const created = await this.prisma.conversation.create({
      data: {
        type: memberIds.length === 2 && !dto.name ? 'DIRECT' : 'GROUP',
        name: dto.name?.trim() || null,
        members: { create: memberIds.map((id) => ({ userId: id, role: id === userId ? 'ADMIN' : 'MEMBER' })) },
      },
      include: { members: { include: { user: { select: publicUser } } }, messages: { take: 1, include: messageInclude } },
    });
    return this.toConversation(created, userId);
  }

  async messages(userId: string, conversationId: string, cursor?: string) {
    await this.assertMember(userId, conversationId);
    return this.prisma.message.findMany({
      where: { conversationId, deletedAt: null },
      include: messageInclude,
      orderBy: { createdAt: 'desc' },
      take: 50,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
  }

  async sendMessage(userId: string, conversationId: string, dto: SendMessageDto) {
    await this.assertMember(userId, conversationId);
    const content = dto.content.trim();
    const onlineRecipient = await this.prisma.user.findFirst({
      where: {
        id: { not: userId },
        isOnline: true,
        memberships: { some: { conversationId } },
      },
      select: { id: true },
    });
    const message = await this.prisma.message.create({
      data: {
        clientMessageId: dto.clientMessageId,
        conversationId,
        senderId: userId,
        content,
        replyToId: dto.replyToId,
        status: onlineRecipient ? 'DELIVERED' : 'SENT',
      },
      include: messageInclude,
    });
    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { lastMessageId: message.id, lastMessageAt: message.createdAt },
    });
    return message;
  }

  async markRead(userId: string, conversationId: string) {
    await this.assertMember(userId, conversationId);
    const readAt = new Date();
    const unread = await this.prisma.message.findMany({
      where: {
        conversationId,
        senderId: { not: userId },
        status: { not: 'READ' },
        deletedAt: null,
      },
      select: { id: true },
    });
    await this.prisma.$transaction([
      this.prisma.conversationMember.update({
        where: { conversationId_userId: { conversationId, userId } },
        data: { lastReadAt: readAt },
      }),
      this.prisma.message.updateMany({
        where: { id: { in: unread.map((message) => message.id) } },
        data: { status: 'READ' },
      }),
    ]);
    return {
      success: true,
      conversationId,
      messageIds: unread.map((message) => message.id),
      readBy: userId,
      readAt,
    };
  }

  async isMember(userId: string, conversationId: string) {
    return Boolean(await this.prisma.conversationMember.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
      select: { id: true },
    }));
  }

  async memberIds(conversationId: string) {
    const members = await this.prisma.conversationMember.findMany({
      where: { conversationId },
      select: { userId: true },
    });
    return members.map((member) => member.userId);
  }

  async setPresence(userId: string, status: 'ONLINE' | 'IDLE' | 'OFFLINE') {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isOnline: status !== 'OFFLINE',
        presenceStatus: status,
        lastSeen: new Date(),
      },
    });
  }

  private async assertMember(userId: string, conversationId: string) {
    const member = await this.prisma.conversationMember.findUnique({ where: { conversationId_userId: { conversationId, userId } } });
    if (!member) throw new ForbiddenException('You are not a member of this conversation');
  }

  private toConversation(
    conversation: any,
    userId: string,
    unreadCount = 0,
  ) {
    const peer = conversation.members.find((member: any) => member.userId !== userId)?.user;
    const lastMessage = conversation.messages[0] ?? null;
    return {
      id: conversation.id,
      type: conversation.type,
      title: conversation.name ?? peer?.displayName ?? 'Conversation',
      peerId: conversation.type === 'DIRECT' ? peer?.id ?? null : null,
      avatarUrl: conversation.avatarUrl ?? peer?.avatarUrl ?? null,
      isOnline: peer?.isOnline ?? false,
      presenceStatus: peer?.presenceStatus ?? 'OFFLINE',
      members: conversation.members.map((member: any) => member.user),
      lastMessage,
      lastMessageAt: conversation.lastMessageAt,
      unreadCount,
    };
  }
}
