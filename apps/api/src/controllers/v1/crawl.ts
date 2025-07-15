import { Request, Response } from "express";
import { WebScraperDataProvider } from "../../scraper/WebScraper";
import { billTeam, checkTeamCredits } from "../../services/billing/credit_billing";
import { authenticateUser } from "../auth";
import { RateLimiterMode } from "../../types";
import { logJob } from "../../services/logging/log_job";
import { addWebScraperJob } from "../../services/queue-jobs";
import { isUrlBlocked } from "../../scraper/WebScraper/utils/blocklist";
import { getWebScraperQueue } from "../../services/queue-service";

export async function crawlHelper(
  req: Request,
  team_id: string,
  crawlerOptions: any,
  pageOptions: any
): Promise<{
  success: boolean;
  error?: string;
  data?: any;
  returnCode: number;
}> {
  const url = req.body.url;
  if (!url) {
    return { success: false, error: "Url is required", returnCode: 400 };
  }

  if (isUrlBlocked(url)) {
    return { success: false, error: "Social media scraping is not supported due to policy restrictions.", returnCode: 403 };
  }

  const mode = req.body.mode ?? "crawl";

  if (mode === "single_urls" && !url.includes(",")) {
    try {
      const a = new WebScraperDataProvider();
      await a.setOptions({
        mode: "single_urls",
        urls: [url],
        crawlerOptions: {
          returnOnlyUrls: true,
        },
        pageOptions: pageOptions,
      });

      const docs = await a.getDocuments(false);
      return {
        success: true,
        data: docs,
        returnCode: 200,
      };
    } catch (error) {
      console.error(error);
      return { success: false, error: error.message, returnCode: 500 };
    }
  }

  const job = await addWebScraperJob({
    url: url,
    mode: mode ?? "crawl",
    crawlerOptions: { ...crawlerOptions },
    team_id: team_id,
    pageOptions: pageOptions,
    origin: req.body.origin ?? "api",
  });

  return {
    success: true,
    data: { id: job.id },
    returnCode: 200,
  };
}

export async function crawlController(req: Request, res: Response) {
  try {
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.Crawl
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    const { success: creditsCheckSuccess, message: creditsCheckMessage } =
      await checkTeamCredits(team_id, 1);
    if (!creditsCheckSuccess) {
      return res.status(402).json({ error: "Insufficient credits" });
    }

    const crawlerOptions = req.body.crawlerOptions ?? {};
    const pageOptions = req.body.pageOptions ?? { onlyMainContent: false };
    const origin = req.body.origin ?? "api";

    const startTime = new Date().getTime();
    const result = await crawlHelper(
      req,
      team_id,
      crawlerOptions,
      pageOptions
    );
    const endTime = new Date().getTime();
    const timeTakenInSeconds = (endTime - startTime) / 1000;

    logJob({
      success: result.success,
      message: result.error,
      num_docs: 1,
      docs: result.data ? [result.data] : [],
      time_taken: timeTakenInSeconds,
      team_id: team_id,
      mode: "crawl",
      url: req.body.url,
      crawlerOptions: crawlerOptions,
      pageOptions: pageOptions,
      origin: origin,
    });

    return res.status(result.returnCode).json(result);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}

export async function crawlStatusController(req: Request, res: Response) {
  try {
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.CrawlStatus
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    const job = await getWebScraperQueue().getJob(req.params.jobId);
    if (!job) {
      return res.status(404).json({ error: "Job not found" });
    }

    const { current, current_url, total, current_step } = await job.progress();
    const jobState = await job.getState();
    
    res.json({
      success: true,
      status: jobState,
      current: current,
      current_url: current_url,
      current_step: current_step,
      total: total,
      data: job.returnvalue,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}
