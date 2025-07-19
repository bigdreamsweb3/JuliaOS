// tools/llmTools.ts
import { AgentContext } from '@juliaos/framework';

export async function extractResearchMetadata(input: any, context: AgentContext) {
  const prompt = `
You are a research assistant helping identify metadata from bounty-related input.

Given this input:
${input.content ?? input.url}

Extract the following fields as JSON:
- topic: main theme of the input
- depth: "light", "medium", or "deep"
- focus: array of relevant focus areas like ["technology", "adoption", "performance"]
- timeframe: e.g. "last_6_months", "last_30_days", etc.

Respond ONLY with valid JSON. Example:
{
  "topic": "Solana DeFi Airdrops",
  "depth": "medium",
  "focus": ["airdrops", "community", "tokenomics"],
  "timeframe": "last_2_months"
}
`;

  const llmResponse = await context.agent.useLLM({
    provider: 'gemini', // ✅ explicitly set Gemini model
    prompt,
    format: 'json',
  });

  try {
    return JSON.parse(llmResponse);
  } catch (e) {
    console.warn('❌ Failed to parse metadata:', llmResponse);
    return {
      topic: 'Web3 Bounty Programs',
      depth: 'medium',
      focus: ['technology'],
      timeframe: 'last_2_months',
    };
  }
}

