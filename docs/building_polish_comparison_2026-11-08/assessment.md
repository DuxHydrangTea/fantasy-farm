# Building pixel cleanup comparison

Each method starts independently from the same transparent, in-game artwork. Only transparent right/bottom padding was added to meet Pixen multiples-of-four input constraints. No artwork resizing. All eight results remain review artifacts; game assets and scenes were not changed.

Comparison images: original / correct_pixelart strength 0.1 / edit_image_pixen. Enlarged exactly 2x with nearest-neighbour sampling.

## Visual assessment

| Building | Correct Pixel Art | Pixen edit | Recommendation |
|---|---|---|---|
| Seed storage | Very subtle changes; roof and wall construction remain largely the same. | More distinct red roof palette and stronger outlines; retains building, door and prop arrangement. Minor details are redrawn. | Most promising Pixen result; review at native size before use. |
| Produce warehouse | Original silhouette and details retained; irregular dormer diagonal and hay texture largely remain. | Adds two blue windows absent from the source; hay is clustered differently but roof line issues remain. | Reject as a faithful cleanup. |
| Cattle barn | Layout and silhouette retained with little visible repair. | Changes roof/fence geometry and prop spacing; bright edge residue remains. | Not a drop-in replacement; original collider alignment would need rechecking. |
| Chicken coop | Original gabled roof and wire run preserved; subtle pixel cleanup. | Replaces the steep gabled roof with a flat dark panel and yellow marks; changes mesh. | Reject Pixen result. |

Correct Pixel Art preserves every input alpha value in these four outputs (measured). It makes widespread RGB changes, so it is visually conservative rather than byte-identical. It still leaves thousands of opaque RGB colours per image and does not fully solve the inherited JPEG/scale artifacts. Pixen reduces each output to around 47-58 opaque RGB colours, but lower colour count is not evidence of faithful architectural repair.

## Cost

Four Correct Pixel Art jobs: 0.4 generations. Four Pixen edits: 4 generations. Total confirmed: 4.4 generations. One API key used. Balance after completion: 1878.40. Receipts and job IDs are in jobs.json; metrics in metrics.json.

Recommendation: do not batch-replace all buildings with either method. Correct Pixel Art is a conservative cleanup step, not a structural repair. Pixen seed storage is the best candidate of this batch; other Pixen outputs require rejection or targeted manual/inpaint repair. No further jobs submitted.
