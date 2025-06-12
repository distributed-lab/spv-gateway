#!/usr/bin/env bash

npx hardhat markup --outdir docs/contracts
cp README.md docs/
docsify generate docs
docsify serve docs