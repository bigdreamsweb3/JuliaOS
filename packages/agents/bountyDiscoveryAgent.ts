import { ApiClient } from "@juliaos/core";
import { ScannerAgent } from "./helper/scannerAgent";
import { CrawlerAgent } from "./helper/crawlerAgent";
import { VerifierAgent } from "./helper/verifierAgent";

// === Agent Metadata ===
const agentConfig = {
  name: "BountyDiscoveryAgent",
  description:
    "Scans URLs, scrapes content from the source, verifies bounty content, and crawls further links for crypto airdrops, bounties, and early opportunities.",
  type: "research",
  research_areas: [
    "airdrops",
    "bounties",
    "early-stage projects",
    "DeFi protocols",
    "Web3 social",
    "crypto gaming",
  ],
  data_sources: [
    "web",
    "api",
    "on-chain data",
    "social media",
    "community forums",
  ],
  analysis_methods: [
    "NLP",
    "sentiment analysis",
    "trend detection",
    "heuristic scoring",
    "pattern matching",
  ],
  output_formats: [
    "text",
    "json",
    "markdown",
    "chart",
    "link previews",
  ],
};

// === Helper: Wait for job result ===
async function waitForResult(client: ApiClient, jobId: string, label: string) {
  while (true) {
    const status = await client.agents.getJobStatus(jobId);
    if (status.status === "COMPLETED") {
      return await client.agents.getJobResult(jobId);
    } else if (["FAILED", "ERROR"].includes(status.status)) {
      throw new Error(`[${label}] Job ${jobId} failed`);
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
}

// === Agent Run Function ===
async function run(input: any, context: any) {
  const client = new ApiClient();

  const seedUrls: string[] =
    input?.seedUrls ?? [
      "https://layer3.xyz",
      "https://galxe.com",
      "https://dappradar.com",
      "https://coinmarketcap.com",
    ];

  const discoveredLinks = new Set<string>();
  const bountyContents: { url: string; content: string }[] = [];

  const scanJobs = await Promise.all(
    seedUrls.map(async (url) => {
      const job = await client.agents.dispatch({
        agent: ScannerAgent,
        input: { links: [url] },
      });
      return { url, scanJobId: job.jobId };
    })
  );

  await Promise.all(
    scanJobs.map(async ({ url, scanJobId }) => {
      try {
        const scanResult = await waitForResult(client, scanJobId, "ScannerAgent");
        const content = scanResult?.results?.[0]?.content;
        if (!content) return;

        const verifyJob = await client.agents.dispatch({
          agent: VerifierAgent,
          input: { url, content },
        });
        const verifyResult = await waitForResult(client, verifyJob.jobId, "VerifierAgent");

        if (!verifyResult?.isBounty) return;

        const bountyData = { url, content };
        bountyContents.push(bountyData);

        // ✅ Save discovered bounty to memory (not "verifiedBounties")
        await context.memory.store("bounty_discovery", {
          type: "discovered_bounty",
          source: bountyData.url,
          content: bountyData.content,
        });

        const crawlJob = await client.agents.dispatch({
          agent: CrawlerAgent,
          input: { content },
        });
        const crawlResult = await waitForResult(client, crawlJob.jobId, "CrawlerAgent");

        if (crawlResult?.links?.length) {
          crawlResult.links.forEach((link: string) => discoveredLinks.add(link));
        }

        console.log(`[✓] Bounty discovered and stored for ${url}`);
      } catch (err) {
        console.error(`[✗] Error in bounty discovery pipeline for ${url}:`, err);
      }
    })
  );

  // === Return both bounty contents and discovered links ===
  return {
    bounties: bountyContents,
    discoveredLinks: [...discoveredLinks],
  };
}

// === Final Export ===
export const BountyDiscoveryAgent = {
  config: agentConfig,
  run,
};
                      
