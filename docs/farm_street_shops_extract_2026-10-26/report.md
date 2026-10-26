# Agricultural street-shop extraction and Unzoom

Source: user-supplied Vietnamese_street_shops_landscape_2K_20261026100713.jpg. User excluded internet cafe; the supplied image contains none, so all five storefronts were extracted, including the left laptop repair shop. Crop-seed and flower signage share one storefront and were kept as one asset.

Five AI-assisted transparent cutouts saved in assets/Buildings/Extracted/FarmStreetShops/*_cutout.png. AI extraction can alter details and is not exact pixel masking: seed/flower shop added decorative shrubs and small goods/sign details changed. An initial fruit-tree shop cutout omitted its brown roof; corrected from the source before Unzoom. Adopted cutout includes the roof. Machinery frontage keeps the displayed tractors. Cropped roof tops remain truncated, not reconstructed as complete roof geometry.

All five processed with PixelLab unzoom_image, quantize=-1 via project helper using the newly configured key. Actual charge 0.1 per image, total 0.5 generation. Balance 33.30 -> 32.80. Cutouts and unzoom results retained separately; previous asset sets untouched.

Output dimensions: laptop repair 315x330, seed/flower 312x325, fruit tree 196x212, animal feed 219x185, agricultural machinery 192x219. Unzoom grid detection differs across images; native pixel scale and building sizes are not normalized. White opaque backgrounds are expected from Unzoom; these are not game-ready transparent sprites. Main signs/goods remain recognizable, but Vietnamese diacritics and tiny merchandise may lose detail. No in-engine validation or scene integration. Output records and sizes.json saved alongside preview.png.
