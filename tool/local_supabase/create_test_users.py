#!/usr/bin/env python3
"""Yerel Supabase kopyasında test hesapları açar (varsa dokunmaz).

    python3 tool/local_supabase/create_test_users.py        # test1, test2
    python3 tool/local_supabase/create_test_users.py 5      # test1..test5

Kayıt uygulamadaki gibi /auth/v1/signup ile yapılır (aynı metadata); yerelde
e-posta onayı kapalı olduğu için hesap hemen giriş yapabilir. handle_new_user
trigger'ının profili açtığı da denetlenir. Parola: local_api.TEST_PASSWORD
(yalnızca yerel kopya; LOCAL_TEST_PASSWORD ile değiştirilebilir).
YALNIZCA yerel adrese bağlanır.
"""

import sys

import local_api as api


def ensure_user(i):
    email = api.TEST_EMAIL_FORMAT.format(i)
    try:
        api.sign_up(email, f"Test Kullanıcı {i}")
        state = "açıldı"
    except api.ApiError as e:
        code = e.body.get("error_code") if isinstance(e.body, dict) else None
        if code not in ("user_already_exists", "email_exists"):
            raise
        state = "zaten vardı"
    session = api.sign_in(email)
    token, uid = session["access_token"], session["user"]["id"]
    profile = api.select("profiles", "select=id,name,avatar_id,friend_code,coins,lifetime_points&limit=1", token)
    if not profile or profile[0]["id"] != uid:
        raise SystemExit(f"HATA: {email} için profil yok (handle_new_user çalışmadı?)")
    p = profile[0]
    print(f"{email}: {state}; uid={uid} ad={p['name']!r} avatar={p['avatar_id']} "
          f"arkadaş_kodu={p['friend_code']} kum={p['coins']} puan={p['lifetime_points']}")
    return email, token, p


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    for i in range(1, count + 1):
        ensure_user(i)


if __name__ == "__main__":
    main()
