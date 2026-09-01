import "dotenv/config";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import * as bcrypt from "bcrypt";
import { PrismaClient } from "../generated/prisma/client";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log("🌱 Starting database seeding...");

  // Keep cleanup atomic so a failure cannot leave a half-cleared database.
  await prisma.$transaction([
    prisma.message.deleteMany(),
    prisma.conversationMember.deleteMany(),
    prisma.conversation.deleteMany(),
    prisma.session.deleteMany(),
    prisma.user.deleteMany(),
  ]);

  const passwordHash = await bcrypt.hash("password123", 10);

  // Create Users
  const userWhyApp = await prisma.user.create({
    data: {
      username: "whyapp",
      displayName: "WhyApp Official",
      passwordHash,
      isOnline: false,
      avatarUrl: "https://api.dicebear.com/7.x/bottts/svg?seed=whyapp",
    },
  });

  const userBagus = await prisma.user.create({
    data: {
      username: "bagus",
      displayName: "Bagus Pangestu",
      passwordHash,
      isOnline: false,
      avatarUrl: "https://api.dicebear.com/7.x/avataaars/svg?seed=bagus",
    },
  });

  const userNicole = await prisma.user.create({
    data: {
      username: "nicole",
      displayName: "Nicole",
      passwordHash,
      isOnline: false,
      avatarUrl: "https://api.dicebear.com/7.x/avataaars/svg?seed=nicole",
    },
  });

  const userYoo1ki = await prisma.user.create({
    data: {
      username: "yoo1ki",
      displayName: "Yoo1ki",
      passwordHash,
      isOnline: false,
      avatarUrl: "https://api.dicebear.com/7.x/avataaars/svg?seed=yoo1ki",
    },
  });

  console.log("✅ Users created:", [
    userWhyApp.username,
    userBagus.username,
    userNicole.username,
    userYoo1ki.username,
  ]);

  // Create Direct Conversation between Yoo1ki & WhyApp
  const conv0 = await prisma.conversation.create({
    data: {
      type: "DIRECT",
      members: {
        create: [{ userId: userYoo1ki.id }, { userId: userWhyApp.id }],
      },
    },
  });

  const msg0 = await prisma.message.create({
    data: {
      conversationId: conv0.id,
      senderId: userWhyApp.id,
      content: "Halo! Selamat datang di WhyApp. Semoga berlangganan, hehe!",
      status: "DELIVERED",
    },
  });

  await prisma.conversation.update({
    where: { id: conv0.id },
    data: {
      lastMessageId: msg0.id,
      lastMessageAt: msg0.createdAt,
    },
  });

  // Create Direct Conversation between Bagus & WhyApp
  const conv1 = await prisma.conversation.create({
    data: {
      type: "DIRECT",
      members: {
        create: [{ userId: userBagus.id }, { userId: userWhyApp.id }],
      },
    },
  });

  const msg1 = await prisma.message.create({
    data: {
      conversationId: conv1.id,
      senderId: userWhyApp.id,
      content: "Halo! Selamat datang di WhyApp. Semoga berlangganan, hehe!",
      status: "DELIVERED",
    },
  });

  await prisma.conversation.update({
    where: { id: conv1.id },
    data: {
      lastMessageId: msg1.id,
      lastMessageAt: msg1.createdAt,
    },
  });

  // Create Direct Conversation between Bagus & Nicole
  const conv2 = await prisma.conversation.create({
    data: {
      type: "DIRECT",
      members: {
        create: [{ userId: userBagus.id }, { userId: userNicole.id }],
      },
    },
  });

  const spamCount = 8;
  const messageIntervalMs = 3_000;
  const finalMessageGapMs = 20_000;
  const finalMessageAt = new Date();
  const firstSpamAt =
    finalMessageAt.getTime() -
    finalMessageGapMs -
    (spamCount - 1) * messageIntervalMs;

  await prisma.message.createMany({
    data: Array.from({ length: spamCount }, (_, index) => ({
      conversationId: conv2.id,
      senderId: userNicole.id,
      content: "P",
      status: "DELIVERED",
      createdAt: new Date(firstSpamAt + index * messageIntervalMs),
    })),
  });

  const msg2 = await prisma.message.create({
    data: {
      conversationId: conv2.id,
      senderId: userNicole.id,
      content: "Pinjam dulu seratus bang",
      status: "DELIVERED",
      createdAt: finalMessageAt,
    },
  });

  await prisma.conversation.update({
    where: { id: conv2.id },
    data: {
      lastMessageId: msg2.id,
      lastMessageAt: msg2.createdAt,
    },
  });

  // Create Direct Conversation between Bagus & Yoo1ki
  const conv3 = await prisma.conversation.create({
    data: {
      type: "DIRECT",
      members: {
        create: [{ userId: userBagus.id }, { userId: userYoo1ki.id }],
      },
    },
  });

  const msg3 = await prisma.message.create({
    data: {
      conversationId: conv3.id,
      senderId: userYoo1ki.id,
      content: "Test",
      status: "DELIVERED",
    },
  });

  await prisma.conversation.update({
    where: { id: conv3.id },
    data: {
      lastMessageId: msg3.id,
      lastMessageAt: msg3.createdAt,
    },
  });

  console.log("✅ Conversations seeded successfully!");
}

main()
  .catch((e) => {
    console.error("❌ Seeding failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
