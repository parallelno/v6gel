# Sprite Clustering Using a Spatial Grid

## Problem

Rendering sprites on the screen causes flickering. The flickering occures a beam crossing the sprite rendering line.
The cause looks like the tearing or flickering with half erased, half rendered.

**Current Solution**

Two stage rendering:
- Sprites rendering into a backbuffer.
- Blittering from the backbuffer onto the screen.

The blittering onto the screen takes significant time.

## Idea

Draw sprites directly on the screen excluding backbuffering and excessive mem copy.

Gain:
- Saves memory.
- Save time on blittering.

| Problems | Solutions |
|----------|-----------|
| Bean detection | Use hardware Timer sunced with frame rendering to get the beam position at the sprite rendering time |
| Beam avoidance | Draw only sprites that far enough from the beam. Carefully measure the sprite workload (background rendering, sprite rendering, algo overhead) |
| Sprites can overlap | Find overlaping sprites and render then together, background, then all overlapping |
| No guaranty that all sprites overlap. Rendering all sprites all at once is impossiblwe with beam avoidance | Split overlaping clusters into smaller fixed length groups. Not 100% solution |

## 1. Input and Data Structures

- Maximum of 32 sprites.
- Sprites are sorted, and each `sprite_ID` corresponds to the sprite's index in the array, starting at 0.
- Each sprite stores:
  - `sprite_ID`
  - `sprite_mask` — a bit mask calculated as `1 << sprite_ID`
  - Position and dimensions
- Screen resolution: 256 × 256 pixels.
- Spatial grid: 16 × 16 cells, with each cell covering 16 × 16 pixels.
- Each grid cell stores a `cell_sprite_mask`, containing the bitwise OR of the masks of all sprites occupying that cell:

  `cell_sprite_mask = sprite_mask1 OR sprite_mask2 OR ... OR sprite_maskN`

- Cluster array: 32 entries, each storing a `cluster_sprite_mask` containing the bitwise OR of the masks of all sprites belonging to that cluster. An entry with a mask of zero is considered empty.

## 2. Algorithm

### Step 1: Prepare the Sprite Mask

For each sprite, calculate its bit mask:

`sprite_mask = 1 << sprite_ID`

### Step 2: Process Each Sprite

Process sprites sequentially in ascending `sprite_ID` order.

For the current sprite:

1. Read the `cell_sprite_mask` of every grid cell occupied by the sprite.
2. Combine the read values using bitwise OR to obtain `cumulative_cell_sprite_mask`.
3. While reading each cell, update its mask to include the current sprite:

   `cell_sprite_mask = cell_sprite_mask OR sprite_mask`

### Step 3: Create or Merge Clusters

**Case A: `cumulative_cell_sprite_mask == 0`**

No previously processed sprites occupy the same grid cells.

- Create a new cluster by storing `sprite_mask` in an empty cluster array entry.

**Case B: `cumulative_cell_sprite_mask != 0`**

At least one previously processed sprite occupies one or more of the same grid cells.

1. Include the current sprite in the cumulative mask:

   `cumulative_cell_sprite_mask = cumulative_cell_sprite_mask OR sprite_mask`

2. Scan the cluster array to find all clusters that intersect the cumulative mask.

3. For each cluster, evaluate:

   `cluster_sprite_mask AND cumulative_cell_sprite_mask != 0`

   - **False:** Continue to the next cluster.
   - **True:** Merge the cluster into the cumulative mask:

     `cumulative_cell_sprite_mask = cumulative_cell_sprite_mask OR cluster_sprite_mask`

     Then clear the original cluster entry by setting it to zero.

4. After the scan is complete, store the resulting cumulative mask in an available cluster array entry.

Because each sprite belongs to exactly one cluster, the masks of distinct existing clusters are disjoint. Therefore, merging a cluster into the cumulative mask cannot introduce an intersection with a previously scanned, disjoint cluster. A single pass is sufficient.

### Step 4: Optimize Cluster Array Scanning

Since sprites are processed in ascending `sprite_ID` order, when processing sprite `i`, only sprites with IDs from `0` through `i - 1` have been processed.

Consequently, the number of active clusters cannot exceed `i`. The algorithm can limit cluster-array scanning to at most `i` entries instead of scanning all 32 entries.

To preserve this optimization:

- Keep new cluster entries within the portion of the array that will be scanned.
- Reuse entries cleared during cluster merging.
- Alternatively, maintain a compact list of active clusters or an active-cluster count.

Do not allow a valid cluster entry to remain outside the scanned range.

## 3. Final Result

Each active cluster stores a bit mask containing the IDs of all sprites belonging to that cluster.

The cluster array represents groups of sprites that can be processed together during rendering.

## 4. Additional Benefits: Incremental Grid Updates

The spatial grid also records which sprites occupy each cell. This information can be retained across frames.

If a sprite's position and dimensions have not changed, its grid occupancy does not need to be recalculated.

Only sprites whose positions or dimensions have changed need to have their spatial data updated. For a moved or resized sprite, remove its old mask from its previous cells and add it to its new cells, while preserving the masks of other sprites.

This can reduce per-frame processing overhead when many sprites remain stationary or move infrequently.

**Important:** Cluster membership may still need to be recalculated when sprites move, because their spatial relationships can change even if most other sprites remain stationary.