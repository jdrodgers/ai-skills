---
name: arr-media-cleanup
description: Use when freeing disk space on a media server run by Radarr, Sonarr (or other *arr apps) and Plex — "delete the biggest movies", "prune old seasons", "what can I remove", "free up space before a migration", "stop it re-downloading", watched/unwatched cleanup, or leftover downloads. Covers deleting files through the *arr APIs so nothing re-downloads (unmonitor first, record state, restore later), cross-checking Plex watched status, an editable plan with dry runs and staged applies, and finding space the apps don't track (unmapped folders, download-client leftovers, snapshots).
---

# Freeing space on an *arr + Plex media server

Deleting media is easy to get wrong in two directions: files come straight back because the app is still monitoring them, or something the user wanted is gone for good. The rules below prevent both. Follow `homelab-changes` (read-only by default, approval for every change) and `credentials-handling` (API keys and Plex tokens in git-ignored local config, never printed).

## Rules

- **Delete through the app's API, not the filesystem**, for anything the app manages. A file deleted behind Radarr/Sonarr's back is just "missing" to them and gets searched for again.
- **Unmonitor before deleting.** Do it in the same run, first, so no RSS sync or search can start in between.
- **Record the previous state before changing anything**: which movies, seasons and episodes were monitored, plus file paths, sizes and quality. Save it to a git-ignored local file. Restore uses it to put back exactly what was there; a tag alone loses "was this monitored before?".
- **Tag held items** (e.g. `storage-hold`) so they are visible in the app's UI and can be found later.
- **Keep the entry; delete only the file** unless the user explicitly asks to remove a title entirely. Restore is then one search. For a full removal, add an import exclusion so a list can't re-add it.
- **Plan → dry run → apply.** Every destructive command is a dry run unless `--apply` is given. Build an editable plan file the user can change, show the dry run, and wait for approval.
- **Apply in stages**: run the first apply on a small batch that exercises every code path (a partial season, a full-show unmonitor, a full delete), verify the result through the API, then run the rest.
- **Re-check before applying**: if the plan was built from "watched" data, confirm it is still true at apply time and stop if not.

## API essentials (v3 API, `X-Api-Key` header)

| Need | Radarr | Sonarr |
|---|---|---|
| Sizes | `GET /movie` (`sizeOnDisk`, `movieFile`) | `GET /series` (`statistics`, `seasons[].statistics`) |
| Files | `movieFile.id` | `GET /episodefile?seriesId=` |
| Unmonitor + tag | `PUT /movie/editor` `{movieIds, monitored:false, tags, applyTags:"add"}` | `PUT /series/{id}` (season `monitored`), `PUT /episode/monitor` `{episodeIds, monitored:false}` |
| Stop future episodes | — | series `monitored:false`, `monitorNewItems:"none"` |
| Delete file | `DELETE /moviefile/{id}` | `DELETE /episodefile/{id}` |
| Remove entirely | `DELETE /movie/{id}?deleteFiles=true&addImportExclusion=true` | `DELETE /series/{id}?deleteFiles=true&addImportListExclusion=true` |
| Restore | editor `monitored:true`, then `POST /command {name:"MoviesSearch", movieIds}` | re-monitor, then `SeasonSearch` / `EpisodeSearch` |
| Untracked folders | `GET /rootfolder` → `unmappedFolders` | same |
| Folder sizes without shell access | `GET /filesystem?path=…&includeFiles=true&allowFoldersWithoutTrailingSlashes=true` (recurse) | same |

Without `allowFoldersWithoutTrailingSlashes=true`, `/filesystem` silently returns the parent folder for paths without a trailing slash; double-check listings that look identical.

## Plex watched status

- Use the token owner's view: `GET /library/sections`, then `/library/sections/{key}/all?type=2&includeGuids=1` (shows), `type=4` (episodes, `viewCount`, `lastViewedAt`, `parentIndex`, `index`), `type=1` (movies). Send the token as the `X-Plex-Token` header, page with `X-Plex-Container-Start/Size`.
- Match on IDs, not titles: TVDB for shows (`Guid` `tvdb://`), TMDB/IMDb for movies; fall back to title + year.
- Plex only sees one account's watched state. Say so, and ask whether others in the household watch.
- `viewCount` 0 with a `lastViewedAt` means started but not finished.
- **Episode counts won't always match.** A double-episode file (`S02E16-17`) is one Plex item but two Sonarr episodes; duplicate or stale Plex entries inflate counts. When "fully watched" depends on counts, reconcile file by file before deleting. A file is deletable only if every episode in it is selected.
- Reset a watch status with `/:/unscrobble?key={ratingKey}&identifier=com.plexapp.plugins.library` (do it before the file is deleted).

## Analysis to offer the user

- Biggest items, and the size distribution (a few outliers vs a long flat tail).
- Fully watched older seasons, excluding the newest season of continuing shows by default.
- "Almost watched" seasons (e.g. 20/21) and recently watched items (possible rewatch) as decisions, not defaults.
- Items watched more than once (likely favourites).
- Items that would leave nothing of a show on disk.
- Small items: often not worth the restore effort.
- Alternative to deleting: re-download at a lower quality (4K remux → 1080p is ~80% smaller).

## Space the apps don't track

- **Unmapped folders** in each root folder: hand-made collections and old downloads the cleanup tools never see. Offer delete or import.
- **Download-client leftovers**: completed-but-unimported folders, duplicates left by copy-instead-of-move imports (separate mounts for downloads and library), stray disc images, and logs that never rotate.
- **Fake releases**: "episodes" that are `.exe`, `.scr` or archives with executables. The app refuses to import them, so they pile up in the completed folder. Delete them, warn the user not to open them from a Windows machine, and suggest checking which indexer supplied them.
- **Snapshots and recycle bins**: deleted files still use space if the share has snapshots or a recycle bin. Check before reporting space as freed.

## Reporting

Report freed space per step and the overall total, what is restorable vs gone for good, where the restore record lives (and that it must be kept), and anything left for later.
