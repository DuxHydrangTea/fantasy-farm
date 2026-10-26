# Five Vietnamese street-shop assets

Source: Vietnamese_street_shops_landscape_2K_20261026095723.jpg, supplied by the user. Five separate AI-assisted cutouts saved under assets/Buildings/Extracted/StreetShops/*_cutout.png. Signs and main architecture retained visually; pedestrians/cashier, street and vehicles removed. Areas hidden by people were reconstructed and not recovered as exact original pixels. Cropped roof tops remain incomplete. AI cutouts are interpretations, not pixel-identical masks of the source JPG.

Each cutout was processed once with PixelLab unzoom_image, quantize=-1 using the new configured key through the project MCP helper. Output PNGs *_unzoom.png are opaque on white, consistent with Unzoom's RGB-only grid recovery. Cost 0.1 generation per asset, total 0.5; account balance 33.80 -> 33.30. Request/result records and sizes.json accompany this report.

Sizes: internet cafe 138x218; grocery 302x329; restaurant 189x226; mini market 182x226; laptop repair 178x232. Grid estimates differ and their game-world scale is not normalized. Grocery retains a finer grid and is much larger than the other outputs. Letter shapes and tiny goods can change in extraction/downsampling. Main signs and furniture remain visually recognizable in the native-size contact sheet.

Internet cafe AI cutout included a soft halo and sidewalk; an attempted AI background cleanup did not remove the halo reliably and was not adopted. A free exact PixelLab pixel edit removed the small exterior sidewalk strip from the downscaled output while preserving the blackboard and interior floor. An earlier full-resolution pixel edit was rejected before processing because the side exceeded 1024px. No added generation charge. Records in net-cleanup.json.

Raw cutouts, Unzoom outputs and previous two-building assets all retained. No scene integration, collision or in-engine scale checks. No additional paid generation retries.
