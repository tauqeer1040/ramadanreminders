const { z } = require('zod');

const upsertUserSchema = z.object({
  displayName: z.string().nullish(),
  email: z.string().nullish(),
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
};
