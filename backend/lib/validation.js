const { z } = require('zod');

const upsertUserSchema = z.object({
  displayName: z.string().nullish(),
  email: z.string().nullish(),
  catName: z.string().nullish(),
});

const syncJournalsSchema = z.object({
  displayName: z.string().optional(),
  email: z.string().optional(),
  journals: z.array(z.object({
    id: z.string(),
    text: z.string(),
  })),
});

const createJournalSchema = z.object({
  id: z.string(),
  text: z.string(),
});

const generateAnalogySchema = z.object({
  question: z.string(),
  answer: z.string(),
});

const generateInsightsSchema = z.object({
  journalEntry: z.string(),
});

const awardStarsSchema = z.object({
  action: z.enum(['onboarding_complete', 'quran_read']),
});

const claimBonusSchema = z.object({
  bonus: z.enum(['notification', 'widget']),
});

const purchaseItemSchema = z.object({
  itemId: z.string(),
});

const subscriptionSyncSchema = z.object({
  appUserId: z.string(),
  productId: z.string(),
  status: z.string(),
  expiresAt: z.number().optional(),
  periodType: z.string().optional(),
});

const syncStreakSchema = z.object({
  streak: z.number().int().min(0).max(100000),
});

const acceptInviteSchema = z.object({
  inviterUid: z.string().min(1),
  myName: z.string().nullish(),
  myCat: z.string().nullish(),
});

const transferLifetimeSchema = z.object({
  recipientEmail: z.string().email(),
});

const shieldConsumeSchema = z.object({
  daysGap: z.number().int().min(1).max(7),
});

module.exports = {
  upsertUserSchema,
  syncJournalsSchema,
  createJournalSchema,
  generateAnalogySchema,
  generateInsightsSchema,
  awardStarsSchema,
  claimBonusSchema,
  purchaseItemSchema,
  subscriptionSyncSchema,
  syncStreakSchema,
  acceptInviteSchema,
  transferLifetimeSchema,
  shieldConsumeSchema,
};
