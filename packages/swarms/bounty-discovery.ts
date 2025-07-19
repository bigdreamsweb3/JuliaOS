import { ApiClient } from "@juliaos/core";
import { ScannerAgent } from "../agents/scannerAgent";
import { CrawlerAgent } from "../agents/crawlerAgent";
import { VerifierAgent } from "../agents/verifierAgent";

// === Swarm Objective ===
const swarmObjective = {
  name: "BountyDiscoverySwarm",
  description: "Discovers and analyzes bounty opportunities by scanning and crawling links.",
  parameters: {
    depthLimit: 2,
    maxLinks: 50,
  },
};

// === Swarm Configuration ===
const swarmConfig = {
  algorithm: "PSO",
  numParticles: 10,
  maxIterations: 5,
  inertiaWeight: 0.7,
  cognitiveCoeff: 1.4,
  socialCoeff: 1.6,
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
    await new Promise((r) => setTimeout(r, 1000)); // Poll every 1s
  }
}

// === Run Swarm Logic ===
async function runSwarm() {
  const client = new ApiClient();

  // Register swarm objective
  const objectiveId = await client.swarms.createObjective(swarmObjective);

  // Launch swarm
  const swarmId = await client.swarms.launchSwarm({
    objectiveId,
    config: swarmConfig,
  });

  // === Seed Links ===
  const seedUrls = [
    "https://layer3.xyz",
    "https://galxe.com",
    "https://dappradar.com",
    "https://coinmarketcap.com",
  ];

  const allLinks = new Set<string>();

  // Step 1: Dispatch all ScannerAgent jobs
  const scanJobs = await Promise.all(
    seedUrls.map(async (url) => {
      const job = await client.agents.dispatch({
        agent: ScannerAgent,
        input: { links: [url] },
      });
      return { url, scanJobId: job.jobId };
    })
  );

  // Step 2: Handle each scan pipeline as soon as ready
  await Promise.all(
    scanJobs.map(async ({ url, scanJobId }) => {
      try {
        // Wait for ScannerAgent result
        const scanResult = await waitForResult(client, scanJobId, "ScannerAgent");
        const content = scanResult?.results?.[0]?.content;
        if (!content) return;

        // Dispatch VerifierAgent
        const verifyJob = await client.agents.dispatch({
          agent: VerifierAgent,
          input: { url, content },
        });
        const verifyResult = await waitForResult(client, verifyJob.jobId, "VerifierAgent");
        if (!verifyResult?.isBounty) return;

        // Dispatch CrawlerAgent
        const crawlJob = await client.agents.dispatch({
          agent: CrawlerAgent,
          input: { content },
        });
        const crawlResult = await waitForResult(client, crawlJob.jobId, "CrawlerAgent");

        if (crawlResult?.links?.length) {
          crawlResult.links.forEach((link: string) => allLinks.add(link));
        }

        console.log(`[✓] Completed pipeline for ${url}`);
      } catch (err) {
        console.error(`[✗] Pipeline failed for ${url}:`, err);
      }
    })
  );

  console.log("[Swarm] Final allLinks:", [...allLinks]);

  // === Monitor Swarm ===
  while (true) {
    try {
      const status = await client.swarms.getSwarmStatus(swarmId);
      console.log(`[Swarm] Status:`, status);
      if (["COMPLETED", "ERROR", "STOPPED"].includes(status.status)) break;
      await new Promise((resolve) => setTimeout(resolve, 2000));
    } catch (err) {
      console.error("Swarm monitoring error:", err);
      break;
    }
  }

  // === Retrieve Results ===
  try {
    const result = await client.swarms.getSwarmResult(swarmId);
    console.log(`[Swarm] Best solution found:`, result.bestSolution);
  } catch (err) {
    console.error("Swarm result retrieval error:", err);
  }
}

// === Start Swarm ===
runSwarm().catch((err) => {
  console.error("Swarm error:", err);
});
