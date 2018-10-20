'use strict';

/* global document */
/* eslint-disable no-await-in-loop, no-restricted-syntax */

const fs = require('fs');
const { promisify } = require('util');

const puppeteer = require('puppeteer');

const setTimeoutPromisified = promisify(setTimeout);
const NOT_MODIFIED = 304;

module.exports = async function scrapeByIndex(config) {
  const outFiles = {};
  const formats = Object.keys(config.formats);
  for (const format of formats) {
    outFiles[format] = fs.openSync(`${config.filePrefix}.${format}`, 'a');
    if (fs.fstatSync(outFiles[format]).size === 0) {
      fs.writeSync(outFiles[format], `\uFEFF${config.formats[format].headers}`);
    }
  }

  let browser;
  try {
    browser = await puppeteer.launch({
      headless: false,
      args: ['--start-maximized'],
    });
    const [page] = await browser.pages();
    await page.setViewport({ width: 1280, height: 850 });

    console.log('Getting index URLs...');
    await page.goto(config.indexURL);
    const articleURLs = await page.evaluate(getURLs, config.indexLinkSelector);

    const stateFileName = `${config.filePrefix}.state.log`;
    if (fs.existsSync(stateFileName) && fs.statSync(stateFileName).size !== 0) {
      const lastSavedURL = fs.readFileSync(stateFileName, 'utf8').trim();
      const alreadySavedURLs = articleURLs.indexOf(lastSavedURL) + 1;
      if (alreadySavedURLs > 0) {
        articleURLs.splice(0, alreadySavedURLs);
        console.log(`Starting after: ${lastSavedURL}...`);
      }
    }

    const errorsFile = fs.openSync(`${config.filePrefix}.errors.log`, 'a');

    while (articleURLs.length > 0) {
      await setTimeoutPromisified(config.throttleDelay);
      const articleURL = articleURLs.shift();

      try {
        const response = await page.goto(articleURL, config.gotoOptions);

        if (!response.ok() && response.status() !== NOT_MODIFIED) {
          logError(errorsFile, articleURL,
                   `HTTP error: response status ${
                     response.status()} ${response.statusText()}`);
          articleURLs.unshift(articleURL);
          continue;
        }
      } catch (err) {
        logError(errorsFile, articleURL, `Net error: ${err.message}`);
        articleURLs.unshift(articleURL);
        continue;
      }

      const articleInFormats = await page.evaluate(config.getArticle);

      if (articleInFormats === null) {
        logError(errorsFile, articleURL, 'Parse error.');
        console.log(`Left: ${articleURLs.length}. Skipped: ${articleURL}`);
        continue;
      }

      for (const format of formats) {
        fs.writeSync(outFiles[format], articleInFormats[format]);
      }
      fs.writeFileSync(stateFileName, `\uFEFF${articleURL}\n`);
      console.log(`Left: ${articleURLs.length}. Saved: ${articleURL}`);
    }

    for (const format of formats) {
      if (config.formats[format].footers) {
        fs.writeSync(outFiles[format], config.formats[format].footers);
      }
    }

    console.log('All done.');
  } catch (err) {
    console.error(err);
  } finally {
    if (browser) await browser.close();
  }
};

// Functions to evaluate in a document context.

function getURLs(linkSelector) {
  return Array.from(
    document.querySelectorAll(linkSelector),
    ({ href }) => href,
  );
}

// Utilities.

function logError(logFile, articleURL, message) {
  fs.writeSync(
    logFile,
    `${new Date().toLocaleString()}\n${articleURL}\n${message}\n\n`,
  );
  console.error(`${message} ( ${articleURL} ).`);
}
