#!/usr/bin/env bash
# Finds the most recent "Merge pull request" commit on the current branch.
# Used by the flc-rocky-reviewer skill as the diff base for branch reviews.
MERGE_COMMIT=$(git log --oneline | grep "Merge pull request" | head -n 1 | cut -d' ' -f1)
echo "$MERGE_COMMIT"
