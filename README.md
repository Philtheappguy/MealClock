# MealClock App Icon (template)

1) Put a 1024×1024 square PNG somewhere (example: `assets/icon_1024.png`).

2) From repo root, run:

```bash
./scripts/generate_appicon.sh assets/icon_1024.png
```

3) Update your `project.yml` so XcodeGen includes the asset catalog:

```yml
targets:
  MealClock:
    resources:
      - path: LaunchScreen.storyboard
      - path: MealClock/Assets.xcassets
    settings:
      base:
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

4) Commit `MealClock/Assets.xcassets` and re-run your CI build.
