﻿/******************************************************************************/
'use strict';
/******************************************************************************/
const common = require('../../common');
const assert = require('assert');

const fs = require('fs');
const path = require('path');
const rl = require('readline');
/******************************************************************************/
const BOM = '\uFEFF';

// get the data by a non-stream way to compare with the streamed data
const modelData = fs.readFileSync(
  path.join(__dirname, 'file-to-read-without-bom.txt'), 'utf8'
);
const modelDataFirstCharacter = modelData[0];

// detect the number of forthcoming 'line' events for mustCall() 'expected' arg
const linesNumber = modelData.match(/\n/g).length;
/******************************************************************************/
// ensure both without-bom and with-bom test files are textwise equal
assert.strictEqual(
  fs.readFileSync(path.join(__dirname, 'file-to-read-with-bom.txt'), 'utf8'),
  `${BOM}${modelData}`
);
/******************************************************************************/
// an unjustified BOM stripping with a non-BOM character unshifted to a stream
const inputWithoutBOM = fs.createReadStream(
  path.join(__dirname, 'file-to-read-without-bom.txt'), 'utf8'
);

inputWithoutBOM.once('readable', common.mustCall(() => {
  const maybeBOM = inputWithoutBOM.read(1);
  assert.strictEqual(maybeBOM, modelDataFirstCharacter);

  if (maybeBOM !== BOM) inputWithoutBOM.unshift(maybeBOM);

  let streamedData = '';
  rl.createInterface({
    input: inputWithoutBOM,
  }).on('line', common.mustCall((line) => {
    streamedData += `${line}\n`;
  }, linesNumber)).on('close', common.mustCall(() => {
    assert.strictEqual(streamedData, modelData);
  }));
}));
/******************************************************************************/
// a justified BOM stripping
const inputWithBOM = fs.createReadStream(
  path.join(__dirname, 'file-to-read-with-bom.txt'), 'utf8'
);

inputWithBOM.once('readable', common.mustCall(() => {
  const maybeBOM = inputWithBOM.read(1);
  assert.strictEqual(maybeBOM, BOM);

  if (maybeBOM !== BOM) inputWithBOM.unshift(maybeBOM);

  let streamedData = '';
  rl.createInterface({
    input: inputWithBOM,
  }).on('line', common.mustCall((line) => {
    streamedData += `${line}\n`;
  }, linesNumber)).on('close', common.mustCall(() => {
    assert.strictEqual(streamedData, modelData);
  }));
}));
/******************************************************************************/
