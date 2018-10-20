'use strict';

/* global document */
/* eslint-disable no-await-in-loop, no-restricted-syntax */

const scrapeByIndex = require('./scrape-by-index.js');

const title = 'Hackterms Dictionary 2018';

const config = {
  filePrefix: 'eng-eng_hackterms.com_2018',

  formats: {
    html: {
      headers: `<!doctype html><html><head><meta charset="UTF-8"><title>${title}</title></head><body>\n\n`,
      footers: '\n</body></html>\n',
    },
    txt: {
      headers: `${title}\nSource: hackterms.com\n\n********************************************************************************\n\n`,
    },
    dsl: {
      headers: `#NAME "${title} (Eng-Eng)"\n#INDEX_LANGUAGE "English"\n#CONTENTS_LANGUAGE "English"\n\n`,
    },
  },

  indexURL: 'https://www.hackterms.com/about/all',
  indexLinkSelector: '#main-section a.all-terms-link[href]',

  throttleDelay: 1000,
  gotoOptions: { timeout: 30000, waitUntil: 'networkidle0' },

  getArticle,
};

scrapeByIndex(config);

// Functions to evaluate in a document context.

async function getArticle() {
  const article = document.querySelector('#definitions-section');
  const heading = article.querySelector('#category-title-label');

  // Just a page with references to other pages, an empty placeholder or an anomaly.
  if (heading === null) return null;

  const articleInFormats = { html: '', txt: '', dsl: '' };

  const TXT_DELIMITER_WIDTH = 80;
  const txtDelimiter = '*'.repeat(TXT_DELIMITER_WIDTH);

  const dslEmptyLine = '[!trs]\\ [/!trs]\n';

  // Main structure unhiding and cleaning.

  // Unfold hidden elements to activate their .innerText value.
  // Delete empty placeholders.
  const commentUnfolders = article.querySelectorAll('.comment-on-post');
  for (const unfolder of commentUnfolders) {
    const commentSection = article.querySelector(
      `.comments-section[data-id="${unfolder.dataset.id}"]`
    );
    if (unfolder.querySelector('.comment-count').innerText !== '0') {
      unfolder.click();
      while (commentSection.style.display === 'none') await waitALittleBit();
    } else {
      commentSection.parentNode.removeChild(commentSection);
    }
  }

  // Delete unneeded elements.
  const selectorsForCleaning = [
    '.definition-actions',
    '.definition-history .definition-term',
    '.add-one',
    '#definition-section-button-wrapper',
  ];
  selectorsForCleaning
    .flatMap(selector => [...article.querySelectorAll(selector)])
    .forEach((element) => { element.parentNode.removeChild(element); });

  articleInFormats.html = `${article.outerHTML}\n\n`;

  // Preformat some elements for plain text and DSL variants.

  const scores = article.querySelectorAll('.definition-score');
  for (const score of scores) {
    score.textContent = `Voting: ${score.textContent}`;
  }

  const docOrigin = document.location.origin;
  const externalLinks = [...article.querySelectorAll('a[href]')]
                          .filter(({ origin }) => origin !== docOrigin);
  for (const externalLink of externalLinks) {
    externalLink.parentNode.insertBefore(
      document.createTextNode(` (${externalLink.href})`),
      externalLink.nextSibling
    );
  }

  // Build plain text and DSL variants piece by piece.

  const headingText = heading.innerText.trim();
  articleInFormats.txt = `${headingText}\n\n`;
  articleInFormats.dsl = `${preprocessDSLHeading(headingText)}\n`;

  const categorySummary = article.querySelector('#category-summary');

  const categoryTitleNodes =
    categorySummary.querySelector('.category-title').childNodes;
  articleInFormats.txt +=
    `${categoryTitleNodes[0].nodeValue}"${
      categoryTitleNodes[1].innerText}"${
      categoryTitleNodes[2].nodeValue}\n`;
  articleInFormats.dsl +=
    `${preprocessDSLBodyPart(categoryTitleNodes[0].nodeValue)}[b]${
      preprocessDSLBodyPart(categoryTitleNodes[1].innerText)}[/b]${
      preprocessDSLBodyPart(categoryTitleNodes[2].nodeValue)}\n`;

  const categoryBarSections = Array.from(
    categorySummary.querySelectorAll('.category-bar .category-stat'),
    ({ innerText }) => innerText
  );
  const categoryLegendLabels = Array.from(
    categorySummary.querySelectorAll('.category-legend .category-label'),
    ({ innerText }) => innerText
  );
  categoryLegendLabels.forEach((text, i) => {
    const stat = categoryBarSections[i];
    articleInFormats.txt += `* ${text}: ${stat}\n`;
    articleInFormats.dsl +=
      `[m2]${preprocessDSLBodyPart(text)}: ${preprocessDSLBodyPart(stat)}[/m]\n`;
  });

  articleInFormats.txt += '\n';
  articleInFormats.dsl += dslEmptyLine;

  const relatedTerms = Array.from(
    categorySummary.querySelectorAll('#related-terms-section a'),
    ({ innerText }) => innerText
  );
  if (relatedTerms.length !== 0) {
    const relatedTermsTitle =
      categorySummary.querySelector('.separator-bar ~ .category-title').innerText;
    articleInFormats.txt +=
      `${relatedTermsTitle} ${relatedTerms.join(', ')}.\n`;
    articleInFormats.dsl +=
      `${preprocessDSLBodyPart(relatedTermsTitle)} ${
        relatedTerms.map(text => `[b]${preprocessDSLBodyPart(text)}[/b]`)
                    .join(', ')}.\n`;
  }

  articleInFormats.txt += '\n';
  articleInFormats.dsl += dslEmptyLine;

  const definitions = article.querySelectorAll('#category-summary ~ .definition');

  for (const definition of definitions) {
    articleInFormats.txt += `${definition.innerText}\n`;
    articleInFormats.dsl +=
      `${preprocessDSLBodyPart(definition.innerText)}\n`;

    const commentSection = article.querySelector(
      `.comments-section[data-id="${definition.id}"]`
    );
    if (commentSection !== null) {
      articleInFormats.txt += `\nComments:\n\n`;
      articleInFormats.dsl += `${dslEmptyLine}[m2][i]Comments:[/i][/m]\n${dslEmptyLine}`;

      articleInFormats.txt += `${commentSection.innerText}\n\n`;
      articleInFormats.dsl +=
        `[m2][i]${preprocessDSLBodyPart(commentSection.innerText)}[/i][/m]\n${dslEmptyLine}`;
    }
  }

  articleInFormats.txt = articleInFormats.txt.trim()
    .replace(/\n[ \t]+\n/gu, '\n\n')
    .replace(/^[ \t]+|[ \t]+$/gmu, '')
    .replace(/\n\n+/gu, '\n\n')
    .replace(/(?<=\n).+(?=\n|$)/gu, '\t$&');
  articleInFormats.dsl = articleInFormats.dsl.trim()
    .replace(/\n[ \t]+\n/gu, '\n\n')
    .replace(/^[ \t]+|[ \t]+$/gmu, '')
    .replace(/\n\n+/gu, `\n${dslEmptyLine}`)
    .replace(/\n(?:\[!trs\]\\ \[\/!trs\]\n?)+$/u, '')
    .replace(/\[!trs\]\\ \[\/!trs\]\n(?:\[!trs\]\\ \[\/!trs\]\n)+/gu, dslEmptyLine)
    .replace(/(?<=\n).+(?=\n|$)/gu, '\t$&');

  articleInFormats.txt += `\n\n${txtDelimiter}\n\n`;
  articleInFormats.dsl += '\n\n';

  return articleInFormats;

  // Utilities.

  function waitALittleBit() {
    const delayMs = 100;
    return new Promise((resolve) => { setTimeout(resolve, delayMs); });
  }

  function preprocessDSLHeading(DSLHeading) {
    const HEADING_MAX_CODE_UNITS = 246;
    const DSLHeadingEscaped = DSLHeading.replace(/[\\#@^~[\]{}()<>]/gu, '\\$&');
    if (DSLHeadingEscaped.length <= HEADING_MAX_CODE_UNITS) {
      return DSLHeadingEscaped;
    }

    const HEADING_MAX_CODE_UNITS_MINUS_ELLIPSIS = 243; // 246 - 3 (for 3 added dots).

    let DSLHeadingTruncated = '';

    for (const codePointCharacter of DSLHeadingEscaped) {
      if (`${DSLHeadingTruncated}${codePointCharacter}`.length >
          HEADING_MAX_CODE_UNITS_MINUS_ELLIPSIS) {
        DSLHeadingTruncated = `${DSLHeadingTruncated}...`;
        break;
      }
      DSLHeadingTruncated += codePointCharacter;
    }

    return DSLHeadingTruncated;
  }

  function preprocessDSLBodyPart(bodyPart) {
    const BODY_WORD_MAX_CODE_UNITS = 255;

    return bodyPart
      .replace(
        // eslint-disable-next-line require-unicode-regexp
        RegExp(`(?<=^|\\s)\\S{${BODY_WORD_MAX_CODE_UNITS}}\\S+(?=\\s|$)`, 'g'),
        segmentalize
      )
      .replace(/[\\#@^~[\]{}()<>]/gu, '\\$&');
  }

  function segmentalize(match) {
    const BODY_WORD_MAX_CODE_UNITS = 255;
    const connector = /^https?:\/\//u.test(match) ? '' : '-';
    const BODY_WORD_MAX_CODE_UNITS_MINUS_CONNECTOR =
      BODY_WORD_MAX_CODE_UNITS - connector.length;

    let word = '';
    let wordChunk = '';

    for (const codePointCharacter of match) {
      if (`${wordChunk}${codePointCharacter}`.length > BODY_WORD_MAX_CODE_UNITS_MINUS_CONNECTOR) {
        word += `${wordChunk}${connector}\n`;
        wordChunk = codePointCharacter;
      } else {
        wordChunk += codePointCharacter;
      }
    }

    return `${word}${wordChunk}`;
  }
}
