
import { ApiClient } from "@juliaos/core";

const client = new ApiClient();

const agentConfig = {
  name: "ScannerAgent",
    description: "Scans provided links and scrapes visible page content for bounty-related opportunities.",
    };

    export async function run(input: { links: string[] }) {
      const links = input.links || [];
        const results: { url: string; content: string }[] = [];

          for (const url of links) {
              try {
                    const result = await client.tools.run("scrape_article_text", { url });
                          if (result?.text) {
                                  results.push({
                                            url,
                                                      content: result.text,
                                                              });
                                                                    }
                                                                        } catch (error) {
                                                                              console.error(`Failed to scrape ${url}:`, error);
                                                                                  }
                                                                                    }

                                                                                      return { results };
                                                                                      }

                                                                                      export const ScannerAgent = {
                                                                                        config: agentConfig,
                                                                                          run,
                                                                                          };
                                                                                          