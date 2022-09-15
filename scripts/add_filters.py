# https://pastebin.com/i1d4xNAY
import sys
import logging
from getpass import getpass

import requests

logger = logging.getLogger()


if sys.version_info[:2] < (3, 6):
    logger.error("Try again with Python 3.6+")
    sys.exit(1)

#
# LOGIN
#

host = input("host: ").strip().rstrip("/") or sys.exit(1)
username = input("username: ").strip() or sys.exit(1)
password = getpass("password: ").strip() or sys.exit(1)

headers = {"User-Agent": "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:52.0) Gecko/20100101 Firefox/52.0"}

s = requests.Session()
s.headers.update(headers)
try:
    x = s.post(host + "/control/login", json={"name": username, "password": password})
    x.raise_for_status()
except Exception as e:
    logger.exception("Exception attempting login to '%s'", host)
    sys.exit(1)
print("Login Successful!")

#
# LISTUP URLS
#

# https://discourse.pi-hole.net/t/update-the-best-blocking-lists-for-the-pi-hole-alternative-dns-servers-2019/13620
burls = [
    # StevenBlack
    # from pi-hole basics - https://github.com/pi-hole/pi-hole/blob/cbfb58f7a283c2a3e7aad95a834a0287175ccb24/automated%20install/basic-install.sh#L1306
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
    # phishing.army
    "https://phishing.army/download/phishing_army_blocklist.txt",
    # motti/pihole-regex
    "https://raw.githubusercontent.com/mmotti/pihole-regex/master/regex.list",
]
# getting more from https://v.firebog.net/hosts/lists.php?type=nocross
burls_more = "https://v.firebog.net/hosts/lists.php?type=nocross"
try:
    for url in list(requests.get(burls_more, timeout=10).text.splitlines()):
        if url:
            burls.append(url)
    print(f"{len(burls):d} blocklists ready!")
except Exception as e:
    logger.exception("Exception while getting blocklist urls from '%s'", burls_more)
    sys.exit(1)

aurls = [
    "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt",
]
print(f"{len(aurls):d} allowlists ready!")

#
# ADD FILTERS
#

print("Adding filter urls - blocklist")
for i, url in enumerate(burls):
    log_prefix = f"[{i+1:03d}/{len(burls):03d}]"
    try:
        x = s.post(host + "/control/filtering/add_url", json={"url": url, "name": url, "whitelist": False})
        # x.raise_for_status()
        log_body = x.text.replace("--", "").replace(url, "").strip()
        # print('{} {} -- {}'.format(log_prefix, log_body, url))
    except Exception as e:
        log_body = f"ERROR: {str(e).strip()}"
    print(f"{log_prefix} {url} -- {log_body}")

print("Adding filter urls - allowlist")
for i, url in enumerate(aurls):
    log_prefix = f"[{i+1:03d}/{len(aurls):03d}]"
    try:
        x = s.post(host + "/control/filtering/add_url", json={"url": url, "name": url, "whitelist": True})
        # x.raise_for_status()
        log_body = x.text.replace("--", "").replace(url, "").strip()
        # print('{} {} -- {}'.format(log_prefix, log_body, url))
    except Exception as e:
        log_body = f"ERROR: {str(e).strip()}"
    print(f"{log_prefix} {url} -- {log_body}")
