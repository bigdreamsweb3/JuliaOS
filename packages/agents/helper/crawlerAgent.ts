import { ApiClient } from "@juliaos/core";

const client = new ApiClient();

const agentConfig = {
  name: "CrawlerAgent",
    description: "Extracts all hyperlinks from the provided content block.",
    };

    export async function run(input: { content: string }) {
      const content = input.content || "";
        const links: string[] = [];

          // Extract all http/https URLs
            const regex = /https?:\/\/[^\s"'>)]+/g;
              const matches = content.match(regex);

                if (matches) {
                    for (const url of matches) {
                          if (!links.includes(url)) {
                                  links.push(url);
                                        }
                                            }
                                              }

                                                return { links };
                                                }

                                                export const CrawlerAgent = {
                                                  config: agentConfig,
                                                    run,
                                                    };
                                                    