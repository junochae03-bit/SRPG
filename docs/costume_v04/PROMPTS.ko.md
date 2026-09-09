# 민트 공격 포즈 교체 — built-in image_gen

원본14포즈는 수정하지 않고 두 장의 일반공격6/7만 교체했다. 생성 PNG는 그대로 복사했고 스크립트로 픽셀을 가공하지 않았다. 런타임에서는 키색을 메모리 RGBA로 변환한다.

## mint-summer-attacks-v04.png

Edit target: existing mint-summer-sheet.png. Create a replacement atlas containing ONLY TWO sprites: second row third pose (frame6 horizontal sword slash), second row fourth pose (frame7 recovery). Preserve crisp pixel-art, mint side-bun hair, violet eyes, pastel holographic jacket, goggles, summer outfit, sword, proportions and colors. Left horizontal attack, right recovery, identical body scale. Shorten slash arc if needed to fit entirely in left half; recovery sword stays in right half. Exactly2 full-body sprites in one horizontal row, roomy equal cells, pure #FF00FF background, at least100px empty vertical gutter and ample outer margins. No overlap, labels, grid, new poses, shadows or extra objects. Wide landscape atlas. Remaining14 poses remain unchanged in game.

Selected output: exec-1f857e4a-d2e1-478d-86c1-d3ba7cdf6505.png

## mint-silver-knight-attacks-v04.png

Edit target: existing mint-silver-knight-sheet.png. Create a replacement atlas containing ONLY TWO sprites: second row third pose (frame6 horizontal sword thrust/slash), second row fourth pose (frame7 recovery). Preserve crisp pixel-art, mint twin-tail hair, violet eyes, silver-white armor, black neck bow, short white skirt, tall silver boots, teal asymmetric cape, cyan sword, head/body proportions and palette. Left horizontal attack and short cyan arc, right recovery with lowered sword, matching body scale. Sword and slash fit left half; recovery stays right half. Exactly2 full-body sprites in one horizontal row, roomy equal cells, flat #FF00FF background, at least100px empty vertical gutter and ample outer margins. No overlap, labels, grid, new elements, shadows or costume change. Wide landscape atlas. Other14 poses remain unchanged.

Selected output: exec-a32ace2a-f064-463a-8c46-79e75db2c257.png
