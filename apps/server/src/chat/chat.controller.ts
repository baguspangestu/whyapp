import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { AuthUser } from '../auth/jwt.strategy';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';

@Controller('conversations')
export class ChatController {
  constructor(private readonly chat: ChatService, private readonly gateway: ChatGateway) {}

  @Get()
  list(@CurrentUser() user: AuthUser) { return this.chat.conversations(user.id); }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateConversationDto) { return this.chat.createConversation(user.id, dto); }

  @Get(':id/messages')
  messages(@CurrentUser() user: AuthUser, @Param('id') id: string, @Query('cursor') cursor?: string) {
    return this.chat.messages(user.id, id, cursor);
  }

  @Post(':id/messages')
  async send(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: SendMessageDto) {
    const message = await this.chat.sendMessage(user.id, id, dto);
    const memberIds = await this.chat.memberIds(id);
    this.gateway.publishMessage(id, memberIds, message);
    return message;
  }

  @Post(':id/read')
  async read(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const receipt = await this.chat.markRead(user.id, id);
    if (receipt.messageIds.length > 0) {
      const memberIds = await this.chat.memberIds(id);
      this.gateway.publishRead(memberIds, receipt);
    }
    return receipt;
  }
}
