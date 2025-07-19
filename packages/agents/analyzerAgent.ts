import { ResearchAgent } from '@juliaos/framework';
import { extractResearchMetadata } from '../tools/llmTools'; // Make sure this is implemented

// 👇 Setup research agent with defined areas, sources, methods, formats
const researchAgent = await ResearchAgent.create({
  name: 'researchDiscoveredBounty',
  research_areas: [
    'market',
    'technology',
    'sentiment',
    'airdrops',
    'bounties',
    'early-stage projects',
    'DeFi protocols',
    'Web3 social',
    'crypto gaming',
  ],
  data_sources: [
    'web',
    'api',
    'database',
    'on-chain data',
    'social media',
    'community forums',
  ],
  analysis_methods: ['statistical', 'nlp', 'trend'],
  output_formats: ['text', 'json', 'chart'],
});

// ✅ Main agent runner
async function run(input: { url: string; content?: string }, context: any) {
  // Step 1: LLM-powered metadata extraction from content/url
  const { topic, depth, focus, timeframe } = await extractResearchMetadata(input);

  // Step 2: Perform research using the ResearchAgent
  const researchResult = await researchAgent.conductResearch({
    topic: topic ?? 'Web3 Bounty Programs',
    depth: depth ?? 'medium',
    focus: focus ?? ['technology', 'adoption', 'performance'],
    timeframe: timeframe ?? 'last_2_months',
    sources: [input.url, 'academic', 'news', 'social_media'], // Add dynamic + static sources
  });

  return researchResult;
}

export const AnalyzerAgent = {
  name: 'AnalyzerAgent',
  description: 'Analyzes bounty URLs or content using JuliaOS LLM-enhanced research tools.',
  run,
};

