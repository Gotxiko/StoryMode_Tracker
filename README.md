# Story Mode - Tracker

A companion addon for [Story Mode](https://github.com/hejrafa/StoryMode) on WoW Forever. It adds a next-step tracker for the story you're following, at the top of the quest tracker.

Story Mode itself stays the author's official release (CurseForge). This addon only hooks into it from outside, through the `StoryMode` global, so a Story Mode update doesn't need any changes here unless Story Mode renames something.

## What it does

- **Next-step tracker.** Shows the story you last began or continued: the story's plate, and for each open chapter its next quest with objectives, giver and location. In Guided mode it also shows a progress bar. Explorer mode gives nothing away ahead.
- **Following.** Begin/Continue Story and a quest card's Track follow that story.
- **Shift-click** a chapter on the Progress track, or a story card, to track or untrack it. A crosshair marks what's tracked.
- **`/sm tracker`** hides or shows the tracker.
- It joins ParchmentUI's tracker stack when that addon is loaded.

## Install

Needs Story Mode. Put this folder in `Interface\AddOns\StoryMode_Tracker`. For development, link it:

```bat
mklink /J "<WoW>\_forever_\Interface\AddOns\StoryMode_Tracker" "D:\Dev\StoryMode_Tracker"
```

## Saved data

`StoryModeTrackerDB`. On first load it copies the tracker state an older Story Mode fork kept in `StoryModeDB`.
