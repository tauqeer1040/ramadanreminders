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

const emailContinueSnapshotSchema = z.object({
  intention: z.string().max(500).nullish(),
  journalExcerpt: z.string().max(2000).nullish(),
  insights: z.array(z.string().max(500)).max(5).nullish(),
  verse: z.object({
    arabic: z.string().max(1000).nullish(),
    transliteration: z.string().max(1000).nullish(),
    english: z.string().max(1000).nullish(),
    reference: z.string().max(120).nullish(),
  }).nullish(),
  timeSpent: z.string().max(60).nullish(),
}).nullish();

const emailContinueSchema = z.object({
  email: z.string().email(),
  displayName: z.string().max(120).nullish(),
  consentUpdates: z.boolean().nullish(),
  snapshot: emailContinueSnapshotSchema,
});

const externalOfferSessionSchema = z.object({
  external_transaction_token: z.string().min(16).max(4096),
  rc_customer_id: z.string().max(200).nullish(),
});

const transferClaimSchema = z.object({
  token: z.string().min(32).max(128),
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
  emailContinueSchema,
  externalOfferSessionSchema,
  transferClaimSchema,
};
