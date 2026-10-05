"""İstemcinin (lib/) onboarding ve kategori sözleşmesinin Python kopyası.

Değerler elle kopyalanmaz; Dart kaynaklarından okunur. Böylece istemci
değişince bu test de aynı değerlerle çalışır:
- lib/screens/post_auth_onboarding_screen.dart → _recommendedBySegment,
  _generalRecommendations, _categoryPayload, segment düğmeleri
- lib/utils/category_names.dart → kKnownCategoryNames (TR/EN eşlemesi)
- lib/widgets/auth/category_name_dialog.dart → kCategoryPalette
- lib/models/category_model.dart → limitler, initialCategories
- lib/services/supabase_service.dart → ownProfileColumns,
  validUserSegments, onboardingProfileUpdate
"""

import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))


def _read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


ONBOARDING_SRC = _read("lib/screens/post_auth_onboarding_screen.dart")
CATEGORY_SEEDS_SRC = _read("lib/services/onboarding_categories.dart")
NAMES_SRC = _read("lib/utils/category_names.dart")
DIALOG_SRC = _read("lib/widgets/auth/category_name_dialog.dart")
MODEL_SRC = _read("lib/models/category_model.dart")
SERVICE_SRC = _read("lib/services/supabase_service.dart")


def _strings(block):
    return re.findall(r"'((?:[^'\\]|\\.)*)'", block)


def _parse_recommended():
    m = re.search(r"kRecommendedCategoriesBySegment\s*=\s*\{(.*?)\};", CATEGORY_SEEDS_SRC, re.S)
    out = {}
    for seg, body in re.findall(r"'(\w+)'\s*:\s*\[(.*?)\]", m.group(1), re.S):
        out[seg] = _strings(body)
    return out


def _parse_general():
    m = re.search(r"kGeneralCategoryRecommendations\s*=\s*\[(.*?)\];", CATEGORY_SEEDS_SRC, re.S)
    return _strings(m.group(1))


def _parse_segment_buttons():
    # _selectSegment('lgs') ... ve _otherSegment
    segs = re.findall(r"_selectSegment\('(\w+)'\)", ONBOARDING_SRC)
    other = re.search(r"_otherSegment\s*=\s*'(\w+)'", ONBOARDING_SRC).group(1)
    return segs + [other], other


def _parse_known():
    m = re.search(r"kKnownCategoryNames\s*=\s*\[(.*?)\];", NAMES_SRC, re.S)
    return re.findall(r"\('([^']*)',\s*'([^']*)'\)", m.group(1))


def _parse_palette():
    m = re.search(r"kCategoryPalette\s*=\s*\[(.*?)\];", DIALOG_SRC, re.S)
    return _strings(m.group(1))


def _parse_limits():
    free = int(re.search(r"kFreeCategoryLimit\s*=\s*(\d+)", MODEL_SRC).group(1))
    prem = int(re.search(r"kPremiumCategoryLimit\s*=\s*(\d+)", MODEL_SRC).group(1))
    return free, prem


def _parse_initial_categories():
    m = re.search(r"initialCategories\(\)\s*\{(.*?)\n  \}", MODEL_SRC, re.S)
    body = m.group(1)
    names = re.findall(r"name:\s*'([^']*)'", body)
    colors = re.findall(r"Color\(0xFF([0-9A-Fa-f]{6})\)", body)
    icons = re.findall(r"iconName:\s*'([^']*)'", body)
    return [{"name": n, "color_hex": "#" + c.upper(), "icon_name": i} for n, c, i in zip(names, colors, icons)]


def _parse_own_profile_columns():
    m = re.search(r"ownProfileColumns\s*=\s*((?:\s*'[^']*'\s*)+);", SERVICE_SRC)
    return "".join(_strings(m.group(1))).replace(" ", "")


def _parse_valid_segments():
    m = re.search(r"validUserSegments\s*=\s*\{(.*?)\}", SERVICE_SRC, re.S)
    return set(_strings(m.group(1)))


RECOMMENDED = _parse_recommended()
GENERAL = _parse_general()
SEGMENT_BUTTONS, OTHER_SEGMENT = _parse_segment_buttons()
KNOWN = _parse_known()
PALETTE = _parse_palette()
FREE_LIMIT, PREMIUM_LIMIT = _parse_limits()
INITIAL_CATEGORIES = _parse_initial_categories()
OWN_PROFILE_COLUMNS = _parse_own_profile_columns()
VALID_SEGMENTS = _parse_valid_segments()


def _normalize(name):
    # category_names.dart: trim + toLowerCase + U+0307 atılır.
    return name.strip().lower().replace("̇", "")


def known_pair(name):
    n = _normalize(name)
    for tr, en in KNOWN:
        if n == _normalize(tr) or n == _normalize(en):
            return (tr, en)
    return None


def translate_cat_name(name, turkish):
    pair = known_pair(name)
    if pair is None:
        return name
    return pair[0] if turkish else pair[1]


def category_match_key(name):
    pair = known_pair(name)
    return _normalize(name) if pair is None else _normalize(pair[0])


def recommended_for(segment):
    return RECOMMENDED.get(segment, GENERAL)


def category_payload(names, turkish=True):
    """_PostAuthOnboardingScreenState._categoryPayload ile aynı."""
    return [
        {"name": translate_cat_name(n, turkish), "color_hex": PALETTE[i % len(PALETTE)], "icon_name": "book"}
        for i, n in enumerate(names)
    ]


def onboarding_profile_update(birth_year, segment, goal, show, completed_at_iso):
    """SupabaseService.onboardingProfileUpdate ile aynı (segment 'other' → null)."""
    seg = segment if segment in VALID_SEGMENTS else None
    by = birth_year if (birth_year is not None and 1900 <= birth_year <= 2100) else None
    out = {"birth_year": by, "user_segment": seg, "daily_goal_minutes": goal}
    if show is not None:
        out["show_in_social_feed"] = show
    out["onboarding_completed_at"] = completed_at_iso
    return out
