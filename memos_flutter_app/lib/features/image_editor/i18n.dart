import 'package:flutter/widgets.dart';
import 'package:image_editor_plus/image_editor_plus.dart';

import '../../core/app_localization.dart';
import '../../data/models/app_preferences.dart';

class ImageEditorI18n {
  static const Map<String, String> _imageEditorI18nZh = {
    'Crop': '裁剪',
    'Brush': '涂鸦',
    'Text': '文字',
    'Link': '链接',
    'Flip': '翻转',
    'Rotate left': '向左旋转',
    'Rotate right': '向右旋转',
    'Blur': '模糊',
    'Filter': '滤镜',
    'Emoji': '贴纸',
    'Select Emoji': '选择贴纸',
    'Size Adjust': '大小调整',
    'Remove': '删除',
    'Size': '大小',
    'Color': '颜色',
    'Background Color': '背景颜色',
    'Background Opacity': '背景透明度',
    'Slider Filter Color': '滤镜颜色',
    'Slider Color': '颜色',
    'Slider Opicity': '透明度',
    'Reset': '重置',
    'Blur Radius': '模糊半径',
    'Color Opacity': '颜色透明度',
    'Insert Your Message': '输入文字',
    'https://example.com': '输入链接',
  };

  static const Map<String, String> _imageEditorI18nZhHant = {
    'Crop': '裁切',
    'Brush': '塗鴉',
    'Text': '文字',
    'Link': '連結',
    'Flip': '翻轉',
    'Rotate left': '向左旋轉',
    'Rotate right': '向右旋轉',
    'Blur': '模糊',
    'Filter': '濾鏡',
    'Emoji': '貼紙',
    'Select Emoji': '選擇貼紙',
    'Size Adjust': '大小調整',
    'Remove': '刪除',
    'Size': '大小',
    'Color': '顏色',
    'Background Color': '背景顏色',
    'Background Opacity': '背景透明度',
    'Slider Filter Color': '濾鏡顏色',
    'Slider Color': '顏色',
    'Slider Opicity': '透明度',
    'Reset': '重設',
    'Blur Radius': '模糊半徑',
    'Color Opacity': '顏色透明度',
    'Insert Your Message': '輸入文字',
    'https://example.com': '輸入連結',
  };

  static const Map<String, String> _imageEditorI18nJa = {
    'Crop': 'トリミング',
    'Brush': 'ブラシ',
    'Text': 'テキスト',
    'Link': 'リンク',
    'Flip': '反転',
    'Rotate left': '左に回転',
    'Rotate right': '右に回転',
    'Blur': 'ぼかし',
    'Filter': 'フィルター',
    'Emoji': '絵文字',
    'Select Emoji': '絵文字を選択',
    'Size Adjust': 'サイズ調整',
    'Remove': '削除',
    'Size': 'サイズ',
    'Color': '色',
    'Background Color': '背景色',
    'Background Opacity': '背景の透明度',
    'Slider Filter Color': 'フィルター色',
    'Slider Color': '色',
    'Slider Opicity': '透明度',
    'Reset': 'リセット',
    'Blur Radius': 'ぼかし半径',
    'Color Opacity': '色の透明度',
    'Insert Your Message': 'テキストを入力',
    'https://example.com': 'リンクを入力',
  };

  static const Map<String, String> _imageEditorI18nDe = {
    'Crop': 'Zuschneiden',
    'Brush': 'Pinsel',
    'Text': 'Text',
    'Link': 'Link',
    'Flip': 'Spiegeln',
    'Rotate left': 'Nach links drehen',
    'Rotate right': 'Nach rechts drehen',
    'Blur': 'Weichzeichnen',
    'Filter': 'Filter',
    'Emoji': 'Emoji',
    'Select Emoji': 'Emoji auswählen',
    'Size Adjust': 'Größe anpassen',
    'Remove': 'Entfernen',
    'Size': 'Größe',
    'Color': 'Farbe',
    'Background Color': 'Hintergrundfarbe',
    'Background Opacity': 'Hintergrundtransparenz',
    'Slider Filter Color': 'Filterfarbe',
    'Slider Color': 'Farbe',
    'Slider Opicity': 'Transparenz',
    'Reset': 'Zurücksetzen',
    'Blur Radius': 'Weichzeichnungsradius',
    'Color Opacity': 'Farbtransparenz',
    'Insert Your Message': 'Text eingeben',
    'https://example.com': 'Link eingeben',
  };

  static const Map<String, String> _imageEditorI18nEn = {
    'Crop': 'Crop',
    'Brush': 'Brush',
    'Text': 'Text',
    'Link': 'Link',
    'Flip': 'Flip',
    'Rotate left': 'Rotate left',
    'Rotate right': 'Rotate right',
    'Blur': 'Blur',
    'Filter': 'Filter',
    'Emoji': 'Emoji',
    'Select Emoji': 'Select Emoji',
    'Size Adjust': 'Size Adjust',
    'Remove': 'Remove',
    'Size': 'Size',
    'Color': 'Color',
    'Background Color': 'Background Color',
    'Background Opacity': 'Background Opacity',
    'Slider Filter Color': 'Slider Filter Color',
    'Slider Color': 'Slider Color',
    'Slider Opicity': 'Slider Opicity',
    'Reset': 'Reset',
    'Blur Radius': 'Blur Radius',
    'Color Opacity': 'Color Opacity',
    'Insert Your Message': 'Insert Your Message',
    'https://example.com': 'https://example.com',
  };

  static void apply(AppLanguage language) {
    final effective = language == AppLanguage.system
        ? appLanguageFromLocale(
            WidgetsBinding.instance.platformDispatcher.locale,
          )
        : language;
    final map = switch (effective) {
      AppLanguage.zhHans => _imageEditorI18nZh,
      AppLanguage.zhHantTw => _imageEditorI18nZhHant,
      AppLanguage.ja => _imageEditorI18nJa,
      AppLanguage.de => _imageEditorI18nDe,
      _ => _imageEditorI18nEn,
    };
    ImageEditor.setI18n(map);
  }
}
