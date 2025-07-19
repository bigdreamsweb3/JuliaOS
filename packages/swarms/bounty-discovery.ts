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

                                                          // === Seed links ===
                                                            const seedUrls = [
                                                                "https://layer3.xyz",
                                                                    "https://galxe.com",
                                                                        "https://dappradar.com",
                                                                            "https://coinmarketcap.com",
                                                                              ];

                                                                                const allLinks = new Set<string>();

                                                                                  for (const url of seedUrls) {
                                                                                      try {
                                                                                            const scan = await ScannerAgent.run({ links: [url] });

                                                                                                  const content = scan?.results?.[0]?.content || "";
                                                                                                        if (!content) continue;

                                                                                                              const verify = await VerifierAgent.run({ url, content });
                                                                                                                    if (!verify?.isBounty) continue;

                                                                                                                          const crawl = await CrawlerAgent.run({  content });
                                                                                                                                if (crawl?.links?.length) {
                                                                                                                                        crawl.links.forEach((link: string) => allLinks.add(link));
                                                                                                                                              }
                                                                                                                                                  } catch (err) {
                                                                                                                                                        console.error(`Error processing URL ${url}:`, err);
                                                                                                                                                            }
                                                                                                                                                              }

                                                                                                                                                                console.log("[Swarm] All verified + crawled links:", [...allLinks]);

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
