import express from "express";
import { scrapeController } from "../../src/controllers/v1/scrape";
import { crawlController, crawlStatusController } from "../../src/controllers/v1/crawl";

export const v1Router = express.Router();

v1Router.get("/v1/scrape/:url(*)", scrapeController);
v1Router.post("/v1/crawl", crawlController);
v1Router.get("/v1/crawl/:jobId", crawlStatusController);
