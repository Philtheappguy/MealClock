# MealClock Cloud CI (Free build option)

This repo builds a **real unsigned IPA** using **GitHub Actions on macOS**.

## How to use (no Mac required)

1) Create a new GitHub repository and upload these files (or push with git).

2) Go to **Actions** → select **Build unsigned IPA** → **Run workflow**.

3) When it finishes, download the artifact: **MealClock-unsigned-ipa → MealClock.ipa**.

4) Install with Sideloadly (it will re-sign with your Apple ID).

## Notes

- This IPA is **unsigned** (intended for Sideloadly to sign/install).
- If your repo is **public**, GitHub Actions on standard runners is free.
- If your repo is **private**, macOS runner time consumes your monthly free minutes quickly (macOS minutes are multiplied).
