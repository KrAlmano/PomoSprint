#!/usr/bin/env python3
"""Elle koşulan simülatör senaryoları için yeni izole yerel hesap.

`e2e-sim-host-<etiket>@pomosprint.local` açar (yalnızca yerel kopya),
onboarding'i uygulamanın yaptığı gibi bitirir (YKS önerileri, görünürlük
açık) ve kullanıcı kimliğini yazar. Şifre integration_test/support/e2e.dart
`kE2ePassword` sabitidir; eski hazır hesap envanteri kaldırılmıştır.

    python3 tool/local_supabase/e2e/sim/create_host_account.py <etiket>
"""

import datetime
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))

_src = open(os.path.join(ROOT, "integration_test", "support", "e2e.dart"), encoding="utf-8").read()
os.environ["LOCAL_TEST_PASSWORD"] = re.search(r"kE2ePassword = '([^']+)'", _src).group(1)

import local_api  # noqa: E402  (şifre ortamdan okunur)

YKS = ["Matematik", "Fizik", "Kimya", "Biyoloji", "Türkçe", "Tarih", "Coğrafya", "Felsefe"]
PALETTE = ["#E53935", "#1E88E5", "#43A047", "#FB8C00", "#8E24AA", "#00ACC1", "#F4511E", "#3949AB"]


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else datetime.datetime.now().strftime("%m%d%H%M")
    email = f"e2e-sim-host-{tag}@pomosprint.local"
    res = local_api.sign_up(email, "Sim Host")
    token = res["access_token"]
    uid = res["user"]["id"]
    local_api.rpc("setup_onboarding_categories", {
        "p_categories": [
            {"name": n, "color_hex": PALETTE[i], "icon_name": "book"} for i, n in enumerate(YKS)
        ],
    }, token=token)
    local_api.request("PATCH", f"/rest/v1/profiles?id=eq.{uid}", {
        "birth_year": 2007,
        "user_segment": "yks",
        "daily_goal_minutes": 120,
        "show_in_social_feed": True,
        "onboarding_completed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }, token=token)
    print(f"{email} {uid}")


if __name__ == "__main__":
    main()
