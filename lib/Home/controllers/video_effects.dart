
class VideoEffectsService {
  static const Map<String, String> videoFilters = {
    'normal': '',
    'vintage': 'curves=preset=vintage',
    'cool': 'colorbalance=bs=0.3:bh=0.3',
    'warm': 'colorbalance=rs=0.3:rh=0.3',
    'cinematic': 'eq=contrast=1.2:brightness=-0.05',
    'dramatic': 'eq=contrast=1.4:brightness=-0.1',
    'noir': 'colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3',
    'comic': 'edgedetect=low=0.1:high=0.4',
    'pastel': 'hue=s=0.4',
    'neon': 'curves=preset=color_negative',
    'clarendon': 'eq=brightness=0.05:contrast=1.2:saturation=1.2',
    'moon': 'colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3',
    'lark': 'eq=brightness=0.08:contrast=1.1:saturation=1.4',
    'reyes': 'eq=brightness=0.06:contrast=1.1:saturation=0.8',
    'juno': 'eq=brightness=0.04:contrast=1.15:saturation=1.25',
    'slumber': 'eq=brightness=0.02:contrast=0.95:saturation=0.7',
    'aden': 'colorbalance=rs=0.2:gs=0.1:bs=0.3',
    'perpetua': 'eq=contrast=1.05:brightness=0.02',
    'brannan': 'colorchannelmixer=.4:.3:.2:0:.35:.4:.25:0:.2:.3:.4',
    'inkwell': 'colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3',
    'valencia': 'colorbalance=rs=0.1:gs=0.1:bs=0.1:rh=0.1:gh=0.1:bh=0.1',
    'xpro2': 'curves=preset=strong_contrast',
    'lo-fi': 'eq=contrast=1.4:brightness=-0.1',
    'sierra': 'colorbalance=rs=0.15:gs=0.1:bs=0.05',
    'walden': 'colorbalance=bs=0.3:bh=0.3',
    'hefe': 'eq=contrast=1.3:saturation=1.1:brightness=0.05',
    'nashville': 'colorbalance=rs=0.2:gs=0.15:bs=0.1:rh=0.1:gh=0.1:bh=0.1',
    '1977': 'colorbalance=rs=0.2:gs=0.1:bs=0.3:rh=0.1:gh=0.1:bh=0.3',
    'kelvin': 'colorbalance=rs=0.1:gs=0.1:bs=0.3:rh=0.1:gh=0.1:bh=0.3',
    'toaster': 'colorbalance=rs=0.1:gs=0.05:bs=0.2:rh=0.2:gh=0.1:bh=0.1',
    'earlybird': 'colorbalance=rs=0.15:gs=0.1:bs=0.05:rh=0.1:gh=0.05:bh=0.05',
    'sutro': 'colorbalance=rs=0.1:gs=0.05:bs=0.1:rh=0.1:gh=0.05:bh=0.1',
    'amaro': 'eq=contrast=1.1:brightness=0.05:saturation=1.2',
    'willow': 'colorchannelmixer=.4:.3:.2:0:.35:.4:.25:0:.2:.3:.4',
  };

  static String getFilter(String filterName) {
    return videoFilters[filterName] ?? '';
  }

  static List<String> getAvailableFilters() {
    return videoFilters.keys.toList();
  }
}