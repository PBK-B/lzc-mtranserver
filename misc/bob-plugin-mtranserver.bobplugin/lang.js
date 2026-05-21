/**
 * 语言代码映射和支持的语言列表
 */

// Bob语言代码到MTranServer语言代码的映射
const langMap = {
    // 自动检测
    "auto": "auto",
    // 中文
    "zh-Hans": "zh-Hans",
    "zh-Hant": "zh-Hant",
    // 英语
    "en": "en",
    // 日语
    "ja": "ja",
    // 韩语
    "ko": "ko",
    // 法语
    "fr": "fr",
    // 德语
    "de": "de",
    // 西班牙语
    "es": "es",
    // 意大利语
    "it": "it",
    // 俄语
    "ru": "ru",
    // 葡萄牙语
    "pt": "pt",
    // 阿拉伯语
    "ar": "ar",
    // 波兰语
    "pl": "pl",
    // 波斯语
    "fa": "fa"
};

// 支持的语言列表
const supportLanguages = [
    "auto",
    "zh-Hans",
    "zh-Hant",
    "en",
    "ja",
    "ko",
    "fr",
    "de",
    "es",
    "it",
    "ru",
    "pt",
    "ar",
    "pl",
    "fa"
];

module.exports = {
    langMap,
    supportLanguages
};
