import { ApiClient } from "@juliaos/core";

const client = new ApiClient();

const agentConfig = {
  name: "VerifierAgent",
    description: "Checks if a link is related to bounties and marks non-bounty links to be ignored.",
    };

    export async function run(input: { url: string; content: string }) {
      const { url, content } = input;

        const bountyKeywords = [
            "bounty", "airdrop", "campaign", "layer3", "galxe", "quest", "task", "reward"
              ];

                const lowerContent = content.toLowerCase();
                  const containsKeyword = bountyKeywords.some(keyword => lowerContent.includes(keyword));

                    if (!containsKeyword) {
                        await client.ignoreLink(url, {
                              reason: "No bounty-related keywords found",
                                    checkedAt: Date.now(),
                                        });
                                          }

                                            return {
                                                url,
                                                    isBounty: containsKeyword,
                                                      };
                                                      }

                                                      export const VerifierAgent = {
                                                        config: agentConfig,
                                                          run,
                                                          };
                   //                                       