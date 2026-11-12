// 体型规格：所有帧都是「同一只水豚」的标准（2026-11-11 和用户定）。
//
// - 标准体型取「侧面坐姿」和「正面那颗头」现场量出来，这里只写比例和误差，不抄死数字：
//   改了坐姿，别的姿势跟着按比例对照
// - 三视图：侧面、正面、背面。背面的头和正面同一颗；背面的头顶、地面和侧面坐姿对齐
// - 体积：头在任何姿势里一样大；坐、拎、站的整只在坐姿的 95–105%；趴、翻身摊开了，放宽到 100–112%
// - 肚皮：只有露出身体下面时（被拎起来、翻身四脚朝天）才画浅色肚皮，侧面姿势没有

export const VIEWS = Object.freeze(['side', 'front', 'back']);

/** 每种姿势的整只大小（头 + 身体 + 腿 + 爪的格数）：坐姿的多少倍 */
export const FIGURE_RANGE = Object.freeze({
  sit: [0.95, 1.05],
  hold: [0.95, 1.05],
  stand: [0.95, 1.05],
  lie: [1.0, 1.12],
  flip: [1.0, 1.12],
});

export const HEAD_RULES = Object.freeze({
  /** 头的格数和标准头差多少算一样（歪头、转头会多一两格少一两格） */
  areaTolerance: 0.03,
  /** 头的宽、高差几格算一样 */
  sizeTolerance: 2,
});

export const THREE_VIEW_RULES = Object.freeze({
  /** 正面头和侧面头一样高（含耳朵），最多差几格 */
  headHeightTolerance: 1,
  /** 正面头的宽 : 侧面头的长（水豚脑袋从侧面看更长），允许的范围 */
  frontWidthToSideLength: [0.9, 1.2],
  /** 背面和侧面坐姿的头顶、地面最多差几行 */
  lineTolerance: 1,
});

export const BELLY_RULES = Object.freeze({
  /** 露肚皮的姿势 */
  shownIn: Object.freeze(['hold', 'flip']),
  /** 露肚皮时身体上至少要有这么多格浅色 */
  minPixels: 20,
  /** 不露肚皮时，身体上的浅色只能是背上那道高光 */
  maxPixelsElsewhere: 6,
});

/**
 * 每帧是什么视角、什么姿势（按素材路径认）。
 * partial：只露出一部分（贴边探头、从道具后面探出来），只比头，不比整只。
 * rotated：整帧转了 90°（贴边转头），头的宽高对调着比。
 * 从上往下第一条对上的为准
 */
export const FRAME_KINDS = Object.freeze([
  { match: /^ui\/item_/, skip: true },
  { match: /^edge\/peek/, view: 'front', partial: true, rotated: true },
  { match: /^ui\/bar_peek/, view: 'front', partial: true },
  { match: /^edge\/turn/, view: 'side', partial: true, rotated: true },
  { match: /^work\/(read|write|eat)_/, view: 'front', partial: true },
  { match: /^work\/search_/, view: 'side', pose: 'stand' },
  // 新演法里趴着、翻身的帧（variant-scenes.mjs）
  { match: /^work\/(surf|rest_fish)_/, view: 'side', pose: 'lie' },
  { match: /^work\/fall_[12]\./, view: 'side', pose: 'flip' },
  { match: /^drag\/(hold|dizzy_-?\d)/, view: 'side', pose: 'hold' },
  // 泡澡：坐在木盆里，只露出上半身
  { match: /^idle_act\/bath_/, view: 'side', partial: true },
  { match: /./, view: 'side', pose: 'sit' },
].map(Object.freeze));

export function frameKind(path) {
  return FRAME_KINDS.find((kind) => kind.match.test(path));
}
